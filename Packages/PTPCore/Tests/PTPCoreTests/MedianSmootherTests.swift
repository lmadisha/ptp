import PTPCore
import Testing

@Test func oneReadingIsItsOwnMedian() {
    var smoother = MedianSmoother(window: .seconds(1))

    #expect(smoother.add(reading(2.5, at: 0)) == 2.5)
}

@Test func oddCountReturnsMiddleDistance() {
    var smoother = MedianSmoother(window: .seconds(1))
    _ = smoother.add(reading(7, at: 0))
    _ = smoother.add(reading(2, at: 100))

    #expect(smoother.add(reading(4, at: 200)) == 4)
}

@Test func evenCountAveragesTheTwoMiddleDistances() {
    var smoother = MedianSmoother(window: .seconds(1))
    _ = smoother.add(reading(10, at: 0))
    _ = smoother.add(reading(2, at: 100))
    _ = smoother.add(reading(1, at: 200))

    #expect(smoother.add(reading(5, at: 300)) == 3.5)
}

@Test func oneOutlierDoesNotMoveSteadyMedian() {
    var smoother = MedianSmoother(window: .seconds(1))
    _ = smoother.add(reading(2, at: 0))
    _ = smoother.add(reading(2, at: 100))

    #expect(smoother.add(reading(50, at: 200)) == 2)
}

@Test func readingsOlderThanWindowDropOut() {
    var smoother = MedianSmoother(window: .milliseconds(500))
    _ = smoother.add(reading(20, at: 0))

    #expect(smoother.add(reading(4, at: 501)) == 4)
}

@Test func heartbeatEvictsOldDistancesAndAddsNothing() {
    var smoother = MedianSmoother(window: .seconds(1))
    _ = smoother.add(reading(20, at: 0))
    _ = smoother.add(reading(4, at: 500))

    #expect(smoother.add(heartbeat(at: 1100)) == 4)
    #expect(smoother.add(heartbeat(at: 1600)) == nil)
}

@Test func readingExactlyOneWindowOldDropsOut() {
    var smoother = MedianSmoother(window: .seconds(1))
    _ = smoother.add(reading(20, at: 0))
    _ = smoother.add(reading(8, at: 1))

    #expect(smoother.add(reading(4, at: 1000)) == 6)
}

@Test func lateReadingsUseNewestTimeEvenAfterTheWindowEmpties() {
    var smoother = MedianSmoother(window: .seconds(1))
    _ = smoother.add(heartbeat(at: 1500))

    #expect(smoother.add(reading(20, at: 499)) == nil)
    #expect(smoother.add(reading(4, at: 501)) == 4)
    #expect(smoother.add(reading(20, at: 500)) == 4)
}

private func reading(_ meters: Float, at milliseconds: Int) -> DistanceSample {
    DistanceSample(meters: meters, source: .uwb, time: .milliseconds(milliseconds))
}

private func heartbeat(at milliseconds: Int) -> DistanceSample {
    DistanceSample(meters: nil, source: .ble, time: .milliseconds(milliseconds))
}
