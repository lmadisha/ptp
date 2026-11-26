import Foundation
import PTPCore
import Testing

private let sent = Date(timeIntervalSinceReferenceDate: 1_000)

@Test func standardSirenFreshnessIsThirtySeconds() {
    #expect(DetectionConfig.standard.sirenFreshness == .seconds(30))
}

@Test func aFreshAlarmSoundsTheSiren() {
    let report = WatchReport(state: .alarm, sentAt: sent)
    #expect(report.soundsSiren(at: sent.addingTimeInterval(1)))
    // The watch's clock may run a little ahead of the phone's.
    #expect(report.soundsSiren(at: sent.addingTimeInterval(-1)))
}

@Test func aStaleAlarmDoesNotSoundTheSiren() {
    #expect(!WatchReport(state: .alarm, sentAt: sent).soundsSiren(at: sent.addingTimeInterval(30)))
}

@Test func onlyAlarmSoundsTheSiren() {
    for state in [PTPState.disarmed, .armed, .warning, .lost] {
        #expect(!WatchReport(state: state, sentAt: sent).soundsSiren(at: sent))
    }
}

@Test func aLateReportDoesNotReplaceANewerOne() {
    let armed = WatchReport(state: .armed, sentAt: sent.addingTimeInterval(5))
    let lateAlarm = WatchReport(state: .alarm, sentAt: sent)
    #expect(!lateAlarm.isNewer(than: armed))
    #expect(armed.isNewer(than: lateAlarm))
    #expect(lateAlarm.isNewer(than: nil))
    #expect(!armed.isNewer(than: armed))
}
