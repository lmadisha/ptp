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

@Test func standardLinkRestartDelayIsTwoSeconds() {
    #expect(DetectionConfig.standard.linkRestartDelay == .seconds(2))
}

@Test func standardSeparationThresholdsAndDelays() {
    let config = DetectionConfig.standard
    #expect(config.tickInterval == .milliseconds(500))
    #expect(config.uwbFreshness == .seconds(2))
    #expect(config.rssiWindow == .seconds(5))
    #expect(config.rssiMinSamples == 3)
    #expect(config.farRSSI == -85)
    #expect(config.nearRSSI == -70)
    #expect(config.farRSSI < config.nearRSSI)
    #expect(config.alertDistance == 8)
    #expect(config.eventAlertDistance == 4)
    #expect(config.eventDurations == [.seconds(7200), .seconds(14_400)])
    #expect(config.eventEndGrace == .seconds(900))
    #expect(config.warningDelay == .seconds(2))
    #expect(config.alarmDelay == .seconds(5))
    #expect(config.alarmRepeatInterval == .seconds(1))
    #expect(config.signalLossDelay == .seconds(3))
    #expect(config.linkStartupDelay == .seconds(10))
    #expect(config.suspensionGap == .seconds(3))
    #expect(config.suspensionGap >= config.signalLossDelay)
}
