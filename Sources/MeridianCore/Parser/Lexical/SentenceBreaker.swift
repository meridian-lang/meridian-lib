import Foundation

struct SentenceBreaker: Sendable {
    enum State: Sendable, Equatable {
        case normal
        case inDoubleQuote
        case inBacktick
    }

    enum Event: Sendable, Equatable {
        case doubleQuote
        case backtick
        case other(Character)
    }

    func statementText(from line: String) -> String {
        guard shouldTrimTerminatingPeriod(line) else {
            return line
        }
        ParserTrace.current.log(.tokenize, "sentence-break: trimmed terminating period from \"\(line)\"")
        return String(line.dropLast())
    }

    func shouldTrimTerminatingPeriod(_ line: String) -> Bool {
        guard line.last == "." else {
            return false
        }
        var state = State.normal
        var previous: Character?
        var index = line.startIndex
        while index < line.endIndex {
            let character = line[index]
            if index == line.index(before: line.endIndex), character == ".", state == .normal {
                return !isDecimalPoint(previous: previous, next: nil)
            }
            state = transition(state, on: event(for: character))
            previous = character
            index = line.index(after: index)
        }
        return false
    }

    func transition(_ state: State, on event: Event) -> State {
        switch (state, event) {
        case (.normal, .doubleQuote):
            return .inDoubleQuote
        case (.inDoubleQuote, .doubleQuote):
            return .normal
        case (.normal, .backtick):
            return .inBacktick
        case (.inBacktick, .backtick):
            return .normal
        default:
            return state
        }
    }

    private func event(for character: Character) -> Event {
        switch character {
        case "\"":
            return .doubleQuote
        case "`":
            return .backtick
        default:
            return .other(character)
        }
    }

    private func isDecimalPoint(previous: Character?, next: Character?) -> Bool {
        previous?.isNumber == true && next?.isNumber == true
    }
}
