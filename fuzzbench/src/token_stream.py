import re


def build_pattern(delimiters: list):
    return '(' + '|'.join(map(re.escape, delimiters)) + ')'


class TokenStream:

    def __init__(self, file, pattern):
        self.file = file
        self.pattern = pattern
        self.tokens = []
        self.lineOffset = 0
        self.lineIndex = -1
        pass

    def poll(self):
        token = self.peek()
        self.lineOffset += 1
        return token

    def peek(self):
        while self.lineOffset >= len(self.tokens):
            exist = self.fetch_next_line()
            if not exist:
                return None

        return self.tokens[self.lineOffset]

    def drop_line(self):
        self.fetch_next_line()

    def advance_until(self, value):
        val = self.peek()
        while val != None and val != value:
            self.lineOffset += 1
            val = self.peek()

        return val

    def advance_until_not(self, value):
        val = self.peek()
        while val != None and val == value:
            self.lineOffset += 1
            val = self.peek()

        return val

    def find_sequence(self, sequence):
        found = False
        canary = self.peek()
        while not found and canary != None:
            canary = self.advance_until(sequence[0])
            i = 0
            while canary != None and i < len(sequence) and sequence[i] == self.peek():
                canary = self.poll()
                i += 1

            if i == len(sequence):
                found = True

        return canary

    def fetch_next_line(self):
        line = self.file.readline()
        self.lineIndex += 1
        self.lineOffset = 0
        if line == '':
            self.tokens = []
            return False

        line = re.sub(r'\s', '%%%%', line)
        tokens = re.split(self.pattern, line)

        self.tokens = []
        for token in tokens:
            if token != '%%%%' and token != '':
                self.tokens.append(token)

        return True
