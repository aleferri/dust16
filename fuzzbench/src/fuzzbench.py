
import argparse
import os
import token_stream
import verilog
import fuzzing

command_line = argparse.ArgumentParser(
    prog='fuzzbench',
    description='Create testbench out of verilog module',
    epilog='Copyright Alessio Ferri')
command_line.add_argument('filename')
command_line.add_argument('-d', '--definition',
                          default='compact', choices=['legacy', 'compact'])
command_line.add_argument('-o', '--output', default='testbench.v')
command_line.add_argument('-p', '--pulse', type=int, default=1000)
command_line.add_argument('-c', '--clock')
command_line.add_argument('--reset')
command_line.add_argument('--reset-sensitivity', default='edge-low',
                          choices=['level-high', 'level-low', 'edge-high', 'edge-low'])
command_line.add_argument('-m', '--module')
command_line.add_argument('-s', '--shell', choices=['bash', 'cmd'])

args = command_line.parse_args()

print(args.filename, args.definition, args.output, args.pulse,
      args.clock, args.reset, args.module, args.shell)


def drop_comments(stream: token_stream.TokenStream):
    if stream.peek() == '/':
        stream.poll()
        second_token = stream.poll()
        if second_token == '/':
            stream.drop_line()
        elif second_token == '*':
            stream.poll()
            canary = stream.find_sequence('*/')
            if canary == None:
                print(
                    'Syntax error: expected matching "*/"'
                )
        else:
            print('Syntax error: expected "//", found', '/' + stream.peek())


def parse_pin(stream: token_stream.TokenStream, parameters: dict):
    io = stream.poll()
    kind = stream.poll()

    size = 1
    maybe_square = stream.peek()
    if maybe_square == '[':
        stream.poll()
        msb = stream.poll()

        if msb in parameters:
            msb = parameters[msb]

        stream.poll()  # ':'
        lsb = stream.poll()

        if lsb in parameters:
            lsb = parameters[lsb]

        stream.poll()  # ']'
        size = abs(int(msb) - int(lsb)) + 1

    name = stream.poll()

    print('Pin', name, ', class:', io, ', storage:', kind, ', size:', size)

    return verilog.Pin(io, kind, size, name)

def parse_parameters(stream: token_stream.TokenStream):
    while stream.peek() != '(':
        stream.poll()

    stream.poll()
    
    params = {}

    while stream.peek() != ')':
        while stream.peek() != 'parameter':
            stream.poll()

        stream.poll()
        name = stream.poll()
        stream.poll()
        value = stream.poll()
        params[name] = value

    stream.poll()

    return params

def parse_module(filename, target_module):
    delimiters = [',', '(', ')', '[', ']', ':', ';', '/', '*', '#', '%%%%']
    regex_pattern = token_stream.build_pattern(delimiters)

    pins = {}

    with open(filename, 'r') as source:
        stream = token_stream.TokenStream(source, regex_pattern)
        token = stream.advance_until('module')
        if token == None:
            print('No modules in the specified file')
            exit(0)

        stream.poll()
        module_name = stream.poll()
        if target_module == None:
            target_module = module_name

        while target_module != module_name:
            token = stream.advance_until('module')
            if token == None:
                print('No module', target_module, ' found in file ', filename)
                exit(0)

            stream.poll()
            module_name = stream.poll()

        print('Found module:', module_name)

        while stream.peek() != '(' and stream.peek() != '#':
            stream.poll()

        if stream.peek() == '#':
            parameters = parse_parameters(stream)

            while stream.peek() != '(':
                stream.poll()

        stream.poll()

        while stream.peek() != ')' and stream.peek() != None:
            # read pin io input/output/inout
            # read pin kind wire/reg
            # read pin size [a:b]|epsilon (implied 1)
            # read pin name
            # read line comma
            # drop comments
            parsed_pin = parse_pin(stream, parameters)
            name = parsed_pin.name
            pins[name] = parsed_pin

            if stream.peek() == ',':
                stream.poll()

            drop_comments(stream)

    return verilog.ModuleIO(target_module, pins)

filepath = os.path.abspath(args.filename)

print('Scanning at', filepath)

mIO = parse_module(filepath, args.module)

try:
    if args.clock != None:
        mIO.set_clock(args.clock)
    if args.reset != None:
        mIO.set_reset(args.reset, args.reset_sensitivity)
except Exception as e:
    print(e)

lines = []

mTb = verilog.ModuleInstance('tb_object', mIO)

fuzzer = fuzzing.Fuzzer(mTb)

lines.append("module " + mIO.testbench_name() + ";")
lines.append('')

for pin in mIO.pins.keys():
    lines.append(mIO.decl_pin(pin) + ';')

lines.append('')
lines.append(mTb.to_string())
lines.append('')

if mIO.has_clock():
    clock_signal = mIO.clock
    lines.append('always begin')
    lines.append('    ' + clock_signal + ' = #' + str(args.pulse) +
                 ' ~' + clock_signal + ';')
    lines.append('end')

lines.append('')
lines.append('initial begin')
initial = fuzzer.reset_wave()
initial.into_lines(lines, '    ')

trigger_reset_on = fuzzer.tick_edge_reset_on(args.pulse * 2, {})
for key in trigger_reset_on.keys():
    lines.append('    ' + key + ' = #' + str(args.pulse * 2) +
                 ' ' + trigger_reset_on[key] + ';')

trigger_reset_off = fuzzer.tick_edge_reset_off(args.pulse * 2, {})
for key in trigger_reset_off.keys():
    lines.append('    ' + key + ' = #' + str(args.pulse * 2) +
                 ' ' + trigger_reset_off[key] + ';')
lines.append('end')


lines.append('')
lines.append("endmodule")

for i in range(0, len(lines)):
    lines[i] = lines[i] + "\n"

with open(args.output, 'w') as output:
    output.writelines(lines)

print('Done!')
