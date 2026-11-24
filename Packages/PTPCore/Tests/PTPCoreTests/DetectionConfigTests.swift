import PTPCore
import Testing

@Test func standardHeartbeatIntervalIsOnePositiveSecond() {
    let interval = DetectionConfig.standard.heartbeatInterval
    #expect(interval == .seconds(1))
    #expect(interval > .zero)
}

@Test func standardSmoothingWindowIsOneSecond() {
    #expect(DetectionConfig.standard.smoothingWindow == .seconds(1))
}

@Test func standardSeparationThresholdsAndDelays() {
    let config = DetectionConfig.standard
    #expect(config.tickInterval == .milliseconds(500))
    #expect(config.alertDistance == 8)
    #expect(config.eventAlertDistance == 4)
    #expect(config.warningDelay == .seconds(2))
    #expect(config.alarmDelay == .seconds(5))
    #expect(config.alarmRepeatInterval == .seconds(1))
    #expect(config.signalLossDelay == .seconds(3))
    #expect(config.linkStartupDelay == .seconds(10))
}
