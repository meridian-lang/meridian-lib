import Testing
@testable import MeridianCore

// Direct unit tests for the vendored `StringTemplate`/`StringConvertible`/
// `ResultBuilder` codegen-templating helpers (AGENTS.md pitfalls #10/#11).
// `SwiftEmitter` exercises these broadly but not exhaustively at the
// branch level (single-component blocks, empty blocks, `buildEither`'s
// `else` arm, `+` operators, etc. are easy to never hit through real codegen
// output); this suite targets those directly instead.

@Suite("Vendored StringTemplate / StringConvertible / ResultBuilder")
struct VendoredTemplateHelpersTests {

    // MARK: - StringTemplate: construction + rendering

    @Test("stringLiteral / string interpolation initializers")
    func literalAndInterpolation() {
        let literal: StringTemplate = "hello"
        #expect(literal.toString() == "hello")
        #expect(literal.string == "hello")

        let name = "world"
        let interpolated: StringTemplate = "hello \(name)"
        #expect(interpolated.toString() == "hello world")

        // Call the labeled initializers directly too: the implicit sugar
        // above doesn't reliably route through `init(stringInterpolation:)`
        // for every compiler/optimization configuration, so cover the lines
        // directly regardless of which literal syntax the compiler chooses.
        let direct = StringTemplate(stringInterpolation: "direct")
        #expect(direct.toString() == "direct")
    }

    @Test("init(_ value:) and init(contentsOf:) wrap a single string / a pre-built item list")
    func plainStringAndContentsOfInit() {
        // A non-literal argument keeps the compiler from preferring the
        // `ExpressibleByStringLiteral` conversion path over this exact
        // `init(_ value: String)` overload.
        let word = "plain"
        let plain = StringTemplate(word)
        #expect(plain.toString() == "plain")

        let items: [StringConvertible] = ["a", "b", 3]
        let fromItems = StringTemplate(contentsOf: items)
        #expect(fromItems.toString() == "ab3")
    }

    @Test("init(contents:name:) sets both the content and the template's name")
    func contentsNameInit() {
        let t = StringTemplate(contents: "body", name: "myTemplate")
        #expect(t.toString() == "body")
        #expect(t.name == "myTemplate")
    }

    @Test("default name is \"string\" for the builder-based initializers")
    func defaultName() {
        let t = StringTemplate { "x" }
        #expect(t.name == "string")
    }

    // MARK: - ResultBuilder arms, via @StringConvertibleBuilder closures

    @Test("an empty builder block renders as an empty string")
    func emptyBlock() {
        let t = StringTemplate {}
        #expect(t.toString() == "")
        #expect(t.flatten() == [])
    }

    @Test("a single-expression block (non-variadic buildBlock) renders that one item")
    func singleExpressionBlock() {
        let t = StringTemplate {
            "only"
        }
        #expect(t.toString() == "only")
    }

    @Test("a multi-statement block (variadic buildBlock) concatenates in order")
    func variadicBlock() {
        let t = StringTemplate {
            "a"
            "b"
            "c"
        }
        #expect(t.toString() == "abc")
    }

    @Test("buildOptional: an `if` with no `else` renders its body when true and nothing when false")
    func buildOptionalBothArms() {
        func render(_ flag: Bool) -> String {
            StringTemplate {
                "before"
                if flag {
                    "middle"
                }
                "after"
            }.toString()
        }
        #expect(render(true) == "beforemiddleafter")
        #expect(render(false) == "beforeafter")
    }

    @Test("buildEither: both the `if` and `else` arms of a two-way branch render")
    func buildEitherBothArms() {
        func render(_ flag: Bool) -> String {
            StringTemplate {
                if flag {
                    "then-branch"
                } else {
                    "else-branch"
                }
            }.toString()
        }
        #expect(render(true) == "then-branch")
        #expect(render(false) == "else-branch")
    }

    @Test("buildArray: a `for` loop flattens each iteration's contribution in order")
    func buildArrayForLoop() {
        let t = StringTemplate {
            for i in 0..<3 {
                "\(i),"
            }
        }
        #expect(t.toString() == "0,1,2,")
    }

    @Test("nested StringTemplate values flatten recursively and concatenate")
    func nestedTemplatesFlatten() {
        let inner = StringTemplate {
            "x"
            "y"
        }
        let outer = StringTemplate {
            "before-"
            inner
            "-after"
        }
        #expect(outer.toString() == "before-xy-after")
        #expect(outer.flatten() == ["before-", "x", "y", "-after"])
    }

    @Test("toString(separator:) joins the flattened leaves with the given separator")
    func toStringWithSeparator() {
        let t = StringTemplate {
            "a"
            "b"
            "c"
        }
        #expect(t.toString(separator: "\n") == "a\nb\nc")
        #expect(t.toString(separator: ", ") == "a, b, c")
    }

    @Test("async builder initializer produces the same result as the sync one")
    func asyncBuilderInitializer() async {
        // A closure literal that merely *doesn't* await anything is still a
        // valid argument for the *sync* builder init, so the overload
        // resolver picks that one — `await` on the call site alone doesn't
        // force the async overload. Annotate the closure's type explicitly
        // so only the async initializer's parameter type matches.
        let t = await StringTemplate({ () async -> [StringConvertible] in
            ["async-a", "async-b"]
        })
        #expect(t.toString() == "async-aasync-b")
    }

    // MARK: - append / `+` operators

    @Test("StringTemplate.append returns a new template with the item appended")
    func appendHelper() {
        let base = StringTemplate { "base" }
        let appended = StringTemplate.append(base, with: "extra")
        #expect(appended.toString() == "baseextra")
        // The original is untouched (value semantics).
        #expect(base.toString() == "base")
    }

    @Test("`+` operators append a StringConvertible on either side of a StringTemplate")
    func plusOperators() {
        let t = StringTemplate { "start" }
        let rhs = t + "end"
        #expect(rhs.toString() == "startend")

        let lhs = "start" + t
        #expect(lhs.toString() == "startstart")
    }

    @Test("String `+=` operators append to/from a StringTemplate")
    func plusEqualsOperators() {
        var t = StringTemplate { "a" }
        let t2 = t += "b"
        #expect(t2.toString() == "ab")

        // `String += StringTemplate` appends the *string* onto the *template*
        // (mirroring `StringTemplate.append(rhs, with: lhs)`), so the string
        // ends up last, not first.
        var s = "prefix-"
        let t3 = s += StringTemplate { "suffix" }
        #expect(t3.toString() == "suffixprefix-")
    }

    // MARK: - TabChar

    @Test("TabChar() defaults to a single tab; TabChar(n) repeats it n times")
    func tabChar() {
        #expect(TabChar().toString() == "\t")
        #expect(TabChar(3).toString() == "\t\t\t")
        #expect(TabChar(0).toString() == "")
    }

    // MARK: - ResultBuilder static methods, called directly

    // `@resultBuilder`'s `buildExpression(_: T) -> [T]` intercepts every bare
    // statement before `buildBlock` ever sees it, so the compiler always
    // assembles a block via `buildBlock(_ components: [T]...)` — never via
    // `buildBlock(_ component: T)` or `buildBlock(_ components: T...)`. Those
    // two (and `buildExpression(_: [T])`/`buildLimitedAvailability`, which
    // would need a bare-array statement / an `#available` guard the DSL never
    // produces) are unreachable *through the `@StringConvertibleBuilder`
    // syntax*, but they're still public API on the vendored type — call them
    // directly to cover the lines.
    typealias Builder = ResultBuilder<StringConvertible>

    @Test("buildBlock(_ component:) — the single-non-variadic overload, called directly")
    func buildBlockSingleDirect() {
        let result = Builder.buildBlock("solo")
        #expect(result.count == 1)
        #expect(result[0].toString() == "solo")
    }

    @Test("buildBlock(_ components: T...) — the T-variadic overload, called directly")
    func buildBlockVariadicTDirect() {
        let result = Builder.buildBlock("a", "b", "c")
        #expect(result.map { $0.toString() } == ["a", "b", "c"])
    }

    @Test("buildExpression(_ expression: [T]) — the array-expression overload, called directly")
    func buildExpressionArrayDirect() {
        let result = Builder.buildExpression(["x", "y"] as [StringConvertible])
        #expect(result.map { $0.toString() } == ["x", "y"])
    }

    @Test("buildLimitedAvailability passes its components through unchanged")
    func buildLimitedAvailabilityDirect() {
        let result = Builder.buildLimitedAvailability(["only" as StringConvertible])
        #expect(result.map { $0.toString() } == ["only"])
    }

    // MARK: - StringConvertible conformances

    @Test("Int and String both conform to StringConvertible via toString()")
    func stringConvertibleConformances() {
        let i: StringConvertible = 42
        #expect(i.toString() == "42")

        let s: StringConvertible = "hi"
        #expect(s.toString() == "hi")
    }
}
