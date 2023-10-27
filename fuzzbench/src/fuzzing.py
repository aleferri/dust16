
import verilog


class Wave:

    def __init__(self, delay=0) -> None:
        self.values = {}
        self.delay = delay

    def dump(self) -> None:
        keys = self.values.keys()
        if self.delay > 0 and len(keys) > 0:
            print('#' + self.delay)

        for key in keys:
            print(key, '=', self.values[key], ';')

    def into_lines(self, lines: list, padding: str):
        keys = self.values.keys()
        if self.delay > 0 and len(keys) > 0:
            lines.append(padding + '#' + self.delay)

        for key in keys:
            lines.append(padding + key + ' = ' + self.values[key] + ';')


class Fuzzer:

    def __init__(self, instance: verilog.ModuleInstance) -> None:
        self.instance = instance
        self.elapsed = 0

    def reset_wave(self) -> Wave:
        wave = Wave()

        for pin in self.list_driveables():
            width = pin.width
            zero = '0' * width
            wave.values[pin.name] = str(width) + "'b" + zero

        if self.instance.header.has_reset():
            reset = self.instance.header.reset
            if reset.trigger == 'edge-high':
                wave.values[reset.signal] = "1'b0"
            elif reset.trigger == 'edge-low':
                wave.values[reset.signal] = "1'b1"
            elif reset.trigger == 'level-high':
                wave.values[reset.signal] = "1'b1"
            else:
                wave.values[reset.signal] = "1'b0"

        return wave

    def tick_edge_reset_on(self, elapsed: int, diff: dict) -> dict:
        if self.instance.header.has_reset():
            self.elapsed += elapsed
            reset = self.instance.header.reset
            if reset.trigger == 'edge-high':
                diff[reset.signal] = "1'b1"
            elif reset.trigger == 'edge-low':
                diff[reset.signal] = "1'b0"

        return diff

    def tick_edge_reset_off(self, elapsed: int, diff: dict) -> dict:
        if self.instance.header.has_reset():
            self.elapsed += elapsed
            reset = self.instance.header.reset
            if reset.trigger == 'edge-high':
                diff[reset.signal] = "1'b0"
            elif reset.trigger == 'edge-low':
                diff[reset.signal] = "1'b1"

        return diff

    def list_driveables(self) -> list:
        drivers = []

        for pin in self.instance.header.pins.values():
            if pin.io == 'input':
                drivers.append(pin)

        return drivers
