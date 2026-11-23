import PTPCore
import Testing

@Test func standardHeartbeatIntervalIsOnePositiveSecond() {
    let interval = DetectionConfig.standard.heartbeatInterval
    #expect(interval == .seconds(1))
    #expect(interval > .zero)
}
