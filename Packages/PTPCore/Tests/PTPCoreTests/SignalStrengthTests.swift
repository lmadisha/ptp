import PTPCore
import Testing

// ADR-0009: without a fresh UWB distance, the heartbeat's signal strength decides.
// Synthetic samples only, until the owner's device logs become fixtures.

private func beat(_ ms: Int, _ rssi: Int?) -> DistanceSample {
    DistanceSample(meters: nil, source: .ble, time: .milliseconds(ms), rssi: rssi)
}

private func distance(_ ms: Int, _ meters: Float) -> DistanceSample {
    DistanceSample(meters: meters, source: .uwb, time: .milliseconds(ms))
}

private func armed() -> PTPStateMachine {
    var machine = PTPStateMachine(config: .standard)
    machine.handle(.arm(.normal), at: .zero)
    return machine
}

@Test func aWeakSignalWithoutUWBWarnsThenAlarms() {
    var machine = armed()
    machine.observe(beat(0, -90))
    machine.observe(beat(1000, -90))
    // The third reading makes the window count; the countdown starts here, at 2 s.
    #expect(machine.observe(beat(2000, -90)) == .armed)
    #expect(machine.observe(beat(3000, -90)) == .armed)
    #expect(machine.observe(beat(4000, -90)) == .warning)
    #expect(machine.alarmDeadline == .seconds(9))
    for ms in [5000, 6000, 7000, 8000] {
        #expect(machine.observe(beat(ms, -90)) == .warning)
    }
    #expect(machine.observe(beat(9000, -90)) == .alarm)
}

@Test func tooFewSignalReadingsDecideNothing() {
    var machine = armed()
    machine.observe(beat(0, -95))
    machine.observe(beat(1000, -95))
    #expect(machine.tick(at: .seconds(3)) == .armed)
    #expect(machine.alarmDeadline == nil)
    // Silence, not signal strength, raises this Alarm.
    #expect(machine.tick(at: .seconds(4)) == .alarm)
}

@Test func aFreshUWBDistanceOutranksAWeakSignal() {
    var machine = armed()
    for ms in stride(from: 0, through: 10_000, by: 1000) {
        machine.observe(distance(ms, 1))
        #expect(machine.observe(beat(ms + 100, -95)) == .armed)
    }
}

@Test func signalStrengthTakesOverOnceTheDistanceIsStale() {
    var machine = armed()
    machine.observe(distance(0, 1))
    // Exactly 2 s old is still fresh.
    for ms in [500, 1000, 1500, 2000] {
        machine.observe(beat(ms, -95))
    }
    #expect(machine.alarmDeadline == nil)
    // The first reading after it went stale starts the countdown.
    machine.observe(beat(2500, -95))
    #expect(machine.tick(at: .milliseconds(4499)) == .armed)
    #expect(machine.tick(at: .milliseconds(4500)) == .warning)
}

@Test func betweenTheTwoLevelsTheLastVerdictStands() {
    var inRange = armed()
    for ms in stride(from: 0, through: 10_000, by: 1000) {
        #expect(inRange.observe(beat(ms, -78)) == .armed)
    }

    var over = armed()
    for ms in [0, 1000, 2000, 3000, 4000] { over.observe(beat(ms, -90)) }
    #expect(over.state == .warning)
    // The median moves into the gap: still Warning, and the countdown carries on.
    for ms in [5000, 6000, 7000, 8000] {
        #expect(over.observe(beat(ms, -78)) == .warning)
    }
    #expect(over.observe(beat(9000, -78)) == .alarm)
}

@Test func aStrongSignalCancelsAWarningRaisedBySignal() {
    var machine = armed()
    for ms in [0, 1000, 2000, 3000, 4000] { machine.observe(beat(ms, -90)) }
    #expect(machine.state == .warning)
    // The median of the last 5 s turns strong once three of five readings are.
    machine.observe(beat(5000, -60))
    #expect(machine.observe(beat(6000, -60)) == .warning)
    #expect(machine.observe(beat(7000, -60)) == .armed)
    #expect(machine.alarmDeadline == nil)
}

@Test func theMedianDecidesNotTheLatestReading() {
    var machine = armed()
    for (ms, rssi) in [(0, -60), (1000, -60), (2000, -60), (3000, -99), (4000, -99)] {
        machine.observe(beat(ms, rssi))
    }
    // Two weak readings of five: the median is still strong. Judging by the latest reading would warn at 5 s.
    #expect(machine.tick(at: .seconds(5)) == .armed)
    // A third weak reading turns the median.
    machine.observe(beat(5000, -99))
    #expect(machine.tick(at: .milliseconds(6999)) == .armed)
    #expect(machine.tick(at: .seconds(7)) == .warning)
}

@Test func aMedianExactlyOnALevelIsInsideTheBand() {
    var far = armed()
    for ms in [0, 1000, 2000, 3000, 4000, 5000] { far.observe(beat(ms, -85)) }
    #expect(far.state == .armed)
    for ms in [6000, 7000, 8000, 9000, 10_000] { far.observe(beat(ms, -86)) }
    #expect(far.state == .warning)

    var near = armed()
    for ms in [0, 1000, 2000, 3000, 4000] { near.observe(beat(ms, -90)) }
    #expect(near.state == .warning)
    for ms in [5000, 6000, 7000, 8000] { near.observe(beat(ms, -70)) }
    #expect(near.state == .warning)
}

@Test func aUWBDistanceInRangeClearsAWarningRaisedBySignal() {
    var machine = armed()
    for ms in [0, 1000, 2000, 3000, 4000] { machine.observe(beat(ms, -90)) }
    #expect(machine.state == .warning)
    #expect(machine.observe(distance(4500, 1)) == .armed)
    // While that distance is fresh the weak signal can't warn again.
    #expect(machine.observe(beat(5000, -90)) == .armed)
    #expect(machine.observe(beat(6000, -90)) == .armed)
}

@Test func aStrongSignalDoesNotClearAVerdictRaisedByUWB() {
    var machine = armed()
    for ms in [0, 500, 1000, 1500, 2000, 2500] { machine.observe(distance(ms, 9)) }
    #expect(machine.state == .warning)
    // PTP leaves the screen: no more distances, and Bluetooth is still strong at 9 m.
    for ms in [3000, 4000, 5000, 6000] {
        #expect(machine.observe(beat(ms, -60)) == .warning)
    }
    #expect(machine.observe(beat(7000, -60)) == .alarm)
}

@Test func aStrongSignalDoesNotClearAnEventModeVerdictRaisedByUWB() {
    var machine = PTPStateMachine(config: .standard)
    machine.handle(.arm(.event), at: .zero)
    for ms in [0, 500, 1000, 1500, 2000] { machine.observe(distance(ms, 5)) }
    #expect(machine.state == .warning)
    for ms in [3000, 4000, 5000, 6000] { machine.observe(beat(ms, -60)) }
    #expect(machine.observe(beat(7000, -60)) == .alarm)
}

@Test func afterIHaveItAWeakSignalStaysQuietUntilItHasBeenStrong() {
    var machine = armed()
    for ms in stride(from: 0, through: 9000, by: 1000) { machine.observe(beat(ms, -90)) }
    #expect(machine.state == .alarm)
    #expect(machine.handle(.iHaveIt, at: .milliseconds(9500)) == .armed)
    // The phone is in a pocket: still weak. No new Warning, however long it lasts.
    for ms in stride(from: 10_000, through: 30_000, by: 1000) {
        #expect(machine.observe(beat(ms, -90)) == .armed)
    }
    // Strong once (three of five readings), then weak again: the watch judges by signal again.
    for ms in [31_000, 32_000, 33_000] { machine.observe(beat(ms, -60)) }
    for ms in [34_000, 35_000, 36_000] { #expect(machine.observe(beat(ms, -90)) == .armed) }
    #expect(machine.observe(beat(37_000, -90)) == .armed)
    #expect(machine.observe(beat(38_000, -90)) == .warning)
}

@Test func aDistanceAfterIHaveItLetsSignalStrengthDecideAgain() {
    var machine = armed()
    for ms in stride(from: 0, through: 9000, by: 1000) { machine.observe(beat(ms, -90)) }
    machine.handle(.iHaveIt, at: .milliseconds(9500))
    machine.observe(distance(10_000, 1))
    // The distance goes stale after 2 s; the weak signal then starts a countdown at 13 s.
    for ms in [11_000, 12_000, 13_000, 14_000] { #expect(machine.observe(beat(ms, -90)) == .armed) }
    #expect(machine.observe(beat(15_000, -90)) == .warning)
}

@Test func signalReadingsFromBeforeASuspensionDecideNothing() {
    var machine = armed()
    for (ms, rssi) in [(0, -78), (1000, -78), (2000, -90), (3000, -90)] { machine.observe(beat(ms, rssi)) }
    #expect(machine.state == .armed)
    machine.resumeAfterSuspension(at: .milliseconds(6500))
    // One weak reading after the gap is one reading, not a full window.
    machine.observe(beat(6500, -90))
    #expect(machine.tick(at: .milliseconds(8500)) == .armed)
}

@Test func heartbeatsWithoutASignalReadingChangeNothing() {
    var machine = armed()
    for ms in stride(from: 0, through: 10_000, by: 1000) {
        #expect(machine.observe(beat(ms, nil)) == .armed)
    }
}
