import Foundation
import Testing
@testable import MeridianCore

@Suite("TraceDurationText coverage")
struct TraceDurationTextCoverageTests {

    @Test("seconds formats zero, whole units, and non-divisible fallback")
    func secondsMatrix() {
        #expect(TraceDurationText.seconds(0) == "0 seconds")
        #expect(TraceDurationText.seconds(1) == "1 second")
        #expect(TraceDurationText.seconds(2) == "2 seconds")
        #expect(TraceDurationText.seconds(60) == "1 minute")
        #expect(TraceDurationText.seconds(120) == "2 minutes")
        #expect(TraceDurationText.seconds(3600) == "1 hour")
        #expect(TraceDurationText.seconds(86400) == "1 day")
        #expect(TraceDurationText.seconds(604800) == "1 week")
        #expect(TraceDurationText.seconds(90) == "90 seconds")
        #expect(TraceDurationText.seconds(1.5) == "1.5 seconds")
    }

    @Test("window multiplies TimeUnitAST seconds before formatting")
    func windowWrapper() {
        #expect(TraceDurationText.window((2, .day)) == "2 days")
        #expect(TraceDurationText.window((1, .week)) == "1 week")
        #expect(TraceDurationText.window((120, .second)) == "2 minutes")
        #expect(TraceDurationText.window((90, .second)) == "90 seconds")
    }
}
