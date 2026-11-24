import PTPCore
import Testing

@Test func uwbSampleKeepsItsValues() {
    let sample = DistanceSample(meters: 2.5, source: .uwb, time: .milliseconds(1250))

    #expect(sample.meters == 2.5)
    #expect(sample.source == .uwb)
    #expect(sample.time == .milliseconds(1250))
}

@Test func bluetoothHeartbeatHasNoDistance() {
    let sample = DistanceSample(meters: nil, source: .ble, time: .milliseconds(1500))

    #expect(sample.meters == nil)
    #expect(sample.source == .ble)
}

@Test func sampleEqualityIncludesTime() {
    let sample = DistanceSample(meters: 2.5, source: .uwb, time: .milliseconds(1250))
    let equal = DistanceSample(meters: 2.5, source: .uwb, time: .milliseconds(1250))
    let later = DistanceSample(meters: 2.5, source: .uwb, time: .milliseconds(1251))

    #expect(sample == equal)
    #expect(sample != later)
}
