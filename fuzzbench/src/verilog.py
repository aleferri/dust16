
class Pin:

    def __init__(self, io: str, kind: str, width: int, name: str) -> None:
        self.io = io
        self.kind = kind
        self.width = width
        self.name = name


class ResetSignal:

    def __init__(self, signal, trigger) -> None:
        self.signal = signal
        self.trigger = trigger


class ModuleIO:

    def __init__(self, name: str, pins: dict) -> None:
        self.name = name
        self.pins = pins
        self.clock = None
        self.reset = None

    def testbench_name(self) -> str:
        return self.name + '_tb'

    def set_clock(self, pin: str) -> None:
        if pin not in self.pins:
            raise Exception('Module Error: Clock signal "' +
                            pin + '" not found, but was expected')
        self.clock = pin

    def has_clock(self) -> bool:
        return self.clock != None

    def set_reset(self, pin: str, trigger: str) -> None:
        if pin not in self.pins:
            raise Exception('Module Error: Reset signal "' +
                            pin + '" not found, but was expected')
        self.reset = ResetSignal(pin, trigger)

    def has_reset(self) -> bool:
        return self.reset != None

    def decl_pin(self, name: str) -> str:
        pin = self.pins[name]
        if pin.io == 'input':
            return self.format_type('reg', pin.width) + ' ' + name
        elif pin.io == 'output':
            return self.format_type('wire', pin.width) + ' ' + name
        else:
            return ''

    def format_type(self, kind: str, size: str) -> str:
        return kind + self.format_width(size)

    def format_width(self, size: int) -> str:
        if size == 1:
            return ''

        return '[' + str(size) + ':0]'


class ModuleInstance:

    def __init__(self, name: str, header: ModuleIO) -> None:
        self.name = name
        self.header = header

    def to_string(self) -> str:
        header = self.header.name + ' ' + self.name + '(\n'
        bindings = []
        for pin in self.header.pins.keys():
            bindings.append('    .' + pin + '(' + pin + ')')
        header += ',\n'.join(bindings)
        header += '\n);\n'
        return header
