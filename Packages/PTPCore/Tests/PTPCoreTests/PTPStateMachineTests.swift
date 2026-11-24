import PTPCore
import Testing

private func sample(_ ms: Int, _ meters: Float? = nil) -> DistanceSample {
    DistanceSample(meters: meters, source: meters == nil ? .ble : .uwb, time: .milliseconds(ms))
}

private func armed(_ mode: ArmMode = .normal) -> PTPStateMachine {
    var machine = PTPStateMachine(config: .standard)
    #expect(machine.state == .disarmed)
    #expect(machine.handle(.arm(mode), at: .zero) == .armed)
    return machine
}

private func warning() -> PTPStateMachine {
    var machine = armed()
    machine.observe(sample(0, 9))
    #expect(machine.tick(at: .milliseconds(1999)) == .armed)
    #expect(machine.tick(at: .seconds(2)) == .warning)
    return machine
}

@Test func heartbeatsPreserveOverDistanceUntilAlarm() {
    var machine = warning()
    for ms in [2100, 4000, 6000] {
        #expect(machine.observe(sample(ms)) == .warning)
    }
    #expect(machine.tick(at: .milliseconds(6999)) == .warning)
    #expect(machine.tick(at: .seconds(7)) == .alarm)
    #expect(machine.observe(sample(7100, 1)) == .alarm)
}

@Test func alarmDeadlineIsOnlyAvailableDuringWarning() {
    var machine = armed()
    machine.observe(sample(0, 9))
    #expect(machine.alarmDeadline == nil)
    #expect(machine.tick(at: .seconds(2)) == .warning)
    #expect(machine.alarmDeadline == .seconds(7))
    for ms in [2500, 4500, 6500] {
        machine.observe(sample(ms))
    }
    #expect(machine.tick(at: .seconds(7)) == .alarm)
    #expect(machine.alarmDeadline == nil)
}

@Test func warningAcknowledgmentRestartsTheWarningDelay() {
    var machine = warning()
    #expect(machine.handle(.iHaveIt, at: .seconds(2)) == .armed)
    #expect(machine.alarmDeadline == nil)

    #expect(machine.observe(sample(2500, 9)) == .armed)
    #expect(machine.tick(at: .milliseconds(4499)) == .armed)
    #expect(machine.tick(at: .milliseconds(4500)) == .warning)
}

@Test func warningAcknowledgmentAfterTheDeadlineAcknowledgesTheAlarm() {
    var machine = warning()
    for ms in [2500, 4500, 6500, 8500] {
        machine.observe(sample(ms))
    }
    #expect(machine.state == .alarm)
    #expect(machine.handle(.iHaveIt, at: .seconds(9)) == .armed)
}

@Test func warningAcknowledgmentGetsNoLinkStartupAllowance() {
    var machine = warning()
    machine.handle(.iHaveIt, at: .seconds(2))
    #expect(machine.tick(at: .milliseconds(4999)) == .armed)
    #expect(machine.tick(at: .seconds(5)) == .alarm)
}

@Test func eitherSignalRestartsArmedSilenceTimer() {
    var machine = armed()
    #expect(machine.observe(sample(2999, 4)) == .armed)
    #expect(machine.observe(sample(5998)) == .armed)
    #expect(machine.tick(at: .milliseconds(8997)) == .armed)
    #expect(machine.tick(at: .milliseconds(8998)) == .alarm)
}

@Test func silenceDuringWarningWinsBeforeDistanceAlarm() {
    var machine = warning()
    #expect(machine.observe(sample(2500)) == .warning)
    #expect(machine.tick(at: .milliseconds(5499)) == .warning)
    #expect(machine.tick(at: .milliseconds(5500)) == .alarm)
}

@Test func equalityRestartsWarningDelayAndImmediatelyRecoversWarning() {
    var machine = armed()
    machine.observe(sample(0, 9))
    #expect(machine.observe(sample(1999, 8)) == .armed)
    machine.observe(sample(3000, 9))
    #expect(machine.tick(at: .milliseconds(4999)) == .armed)
    #expect(machine.tick(at: .seconds(5)) == .warning)
    #expect(machine.observe(sample(5001, 8)) == .armed)
    #expect(machine.observe(sample(7001)) == .armed)
}

@Test func eventUsesFourMetersAndRepeatedArmCannotChangeMode() {
    var machine = armed(.event)
    #expect(machine.handle(.arm(.normal), at: .zero) == .armed)
    machine.observe(sample(0, 4))
    #expect(machine.observe(sample(2000)) == .armed)
    machine.observe(sample(2000, 4.1))
    #expect(machine.tick(at: .milliseconds(3999)) == .armed)
    #expect(machine.tick(at: .seconds(4)) == .warning)
}

@Test func distanceVerdictUsesMedian() {
    var machine = armed()
    machine.observe(sample(0, 4))
    machine.observe(sample(100, 4))
    machine.observe(sample(200, 20))
    #expect(machine.observe(sample(2200)) == .armed)
}

@Test func acknowledgmentRestartsSignalLossAtOwnerAction() {
    var machine = armed()
    machine.observe(sample(0))
    #expect(machine.tick(at: .milliseconds(2999)) == .armed)
    #expect(machine.tick(at: .seconds(3)) == .alarm)
    #expect(machine.handle(.iHaveIt, at: .seconds(8)) == .armed)
    #expect(machine.tick(at: .milliseconds(10999)) == .armed)
    #expect(machine.tick(at: .seconds(11)) == .alarm)
}

@Test func armingAllowsLinkStartupSilenceUntilTheFirstSample() {
    var silent = armed()
    #expect(silent.tick(at: .milliseconds(9999)) == .armed)
    #expect(silent.tick(at: .seconds(10)) == .alarm)

    var linked = armed()
    linked.observe(sample(1000))
    #expect(linked.tick(at: .milliseconds(3999)) == .armed)
    #expect(linked.tick(at: .seconds(4)) == .alarm)

    var onTime = armed()
    #expect(onTime.observe(sample(10000)) == .armed)
    var late = armed()
    #expect(late.observe(sample(10001)) == .alarm)
}

@Test func acknowledgmentGetsNoLinkStartupAllowance() {
    var machine = armed()
    #expect(machine.tick(at: .seconds(10)) == .alarm)
    machine.handle(.iHaveIt, at: .seconds(10))
    #expect(machine.tick(at: .milliseconds(12999)) == .armed)
    #expect(machine.tick(at: .seconds(13)) == .alarm)
}

@Test func rearmingAfterASampleAllowsLinkStartupAgain() {
    var machine = armed()
    machine.observe(sample(0))
    machine.handle(.disarm, at: .seconds(1))
    machine.handle(.arm(.normal), at: .zero)
    #expect(machine.tick(at: .milliseconds(9999)) == .armed)
    #expect(machine.tick(at: .seconds(10)) == .alarm)
}

@Test func acknowledgmentClearsSmootherAndCountdownAndRetainsEventMode() {
    var machine = armed(.event)
    machine.observe(sample(0, 10))
    machine.tick(at: .seconds(3))
    #expect(machine.observe(sample(3999, 20)) == .alarm)
    #expect(machine.handle(.iHaveIt, at: .seconds(4)) == .armed)
    #expect(machine.observe(sample(4000)) == .armed)
    #expect(machine.observe(sample(6000)) == .armed)
    machine.observe(sample(6001, 5))
    #expect(machine.tick(at: .milliseconds(8000)) == .armed)
    #expect(machine.tick(at: .milliseconds(8001)) == .warning)
}

@Test func disarmIsImmediateInEveryNonterminalState() {
    var alarm = warning()
    alarm.tick(at: .seconds(3))
    #expect(alarm.state == .alarm)
    for var machine in [PTPStateMachine(config: .standard), armed(), warning(), alarm] {
        #expect(machine.handle(.disarm, at: .seconds(4)) == .disarmed)
        #expect(machine.observe(sample(9999, 20)) == .disarmed)
        #expect(machine.tick(at: .seconds(10)) == .disarmed)
        #expect(machine.handle(.arm(.normal), at: .seconds(10)) == .armed)
        machine.observe(sample(10000))
        #expect(machine.tick(at: .seconds(12)) == .armed)
    }
}

@Test func invalidActionsLeaveStateAndTimersAlone() {
    var machine = PTPStateMachine(config: .standard)
    for action in [OwnerAction.iHaveIt, .markAsLost] {
        #expect(machine.handle(action, at: .zero) == .disarmed)
    }
    machine.handle(.arm(.normal), at: .zero)
    machine.observe(sample(0, 10))
    for action in [OwnerAction.iHaveIt, .markAsLost, .arm(.event)] {
        #expect(machine.handle(action, at: .seconds(1)) == .armed)
    }
    #expect(machine.tick(at: .seconds(2)) == .warning)
    for action in [OwnerAction.markAsLost, .arm(.event)] {
        #expect(machine.handle(action, at: .seconds(2)) == .warning)
    }
    #expect(machine.tick(at: .seconds(3)) == .alarm)
    #expect(machine.handle(.arm(.event), at: .seconds(3)) == .alarm)
    #expect(machine.handle(.markAsLost, at: .seconds(3)) == .lost)
    for action in [OwnerAction.disarm, .iHaveIt, .markAsLost, .arm(.normal)] {
        #expect(machine.handle(action, at: .seconds(4)) == .lost)
    }
    #expect(machine.observe(sample(5000, 1)) == .lost)
    #expect(machine.tick(at: .seconds(10)) == .lost)
}

@Test func olderInputsUseNewestSessionTime() {
    var machine = armed()
    machine.tick(at: .seconds(2))
    machine.observe(sample(0, 10))
    #expect(machine.tick(at: .milliseconds(3999)) == .armed)
    #expect(machine.tick(at: .seconds(4)) == .warning)
    machine.observe(sample(100, 2))
    #expect(machine.state == .armed)
    #expect(machine.tick(at: .milliseconds(6999)) == .armed)
    #expect(machine.tick(at: .seconds(7)) == .alarm)
    machine.handle(.iHaveIt, at: .zero)
    #expect(machine.tick(at: .milliseconds(9999)) == .armed)
}

@Test func sampleAtDeadlineWinsButLateRecoveryCannotCancelAlarm() {
    var machine = armed()
    machine.observe(sample(0))
    #expect(machine.observe(sample(3000)) == .armed)
    #expect(machine.observe(sample(6001, 1)) == .alarm)

    var recovering = warning()
    recovering.observe(sample(2500))
    recovering.observe(sample(4500))
    #expect(recovering.observe(sample(7000, 1)) == .armed)
}

@Test func sparseTicksRespectConfiguredDeadlines() {
    var config = DetectionConfig.standard
    config.alertDistance = 2
    config.warningDelay = .milliseconds(42)
    config.alarmDelay = .milliseconds(30)
    config.signalLossDelay = .milliseconds(100)
    var machine = PTPStateMachine(config: config)
    machine.handle(.arm(.normal), at: .zero)
    machine.observe(sample(0, 3))
    #expect(machine.tick(at: .milliseconds(41)) == .armed)
    #expect(machine.tick(at: .milliseconds(71)) == .warning)
    #expect(machine.tick(at: .milliseconds(72)) == .alarm)
}

@Test func acknowledgmentDiscardsRecentOutOfRangeReadings() {
    var machine = warning()
    for ms in [2500, 4500, 6800, 6900] {
        machine.observe(sample(ms, 20))
    }
    #expect(machine.tick(at: .seconds(7)) == .alarm)
    #expect(machine.handle(.iHaveIt, at: .seconds(7)) == .armed)
    #expect(machine.observe(sample(7000, 1)) == .armed)
    #expect(machine.tick(at: .seconds(9)) == .armed)
}

@Test func heartbeatAgingAMixedWindowPreservesTheLastVerdict() {
    var nearby = armed()
    var separated = armed()
    for ms in [0, 100] {
        nearby.observe(sample(ms, 1))
        separated.observe(sample(ms, 20))
    }
    nearby.observe(sample(200, 20))
    separated.observe(sample(200, 1))
    // Only the outlier remains in each smoothing window at the heartbeat.
    nearby.observe(sample(1100))
    separated.observe(sample(1100))
    #expect(nearby.tick(at: .milliseconds(3100)) == .armed)
    #expect(separated.tick(at: .milliseconds(1999)) == .armed)
    #expect(separated.tick(at: .seconds(2)) == .warning)
}

@Test func rearmingStartsANewTimeBase() {
    var machine = PTPStateMachine(config: .standard)
    machine.handle(.arm(.normal), at: .seconds(0))
    machine.handle(.disarm, at: .seconds(3600))

    machine.handle(.arm(.normal), at: .seconds(0))

    #expect(machine.tick(at: .milliseconds(9999)) == .armed)
    #expect(machine.tick(at: .milliseconds(10000)) == .alarm)
}

@Test func ownerActionAppliesADeadlineThatFellDueFirst() {
    var machine = PTPStateMachine(config: .standard)
    machine.handle(.arm(.normal), at: .seconds(0))
    machine.observe(sample(0))

    // Signal loss fell due at 3 s; the tap at 5 s acknowledges that alarm.
    #expect(machine.handle(.iHaveIt, at: .seconds(5)) == .armed)
    #expect(machine.tick(at: .milliseconds(7999)) == .armed)
    #expect(machine.tick(at: .milliseconds(8000)) == .alarm)
}

@Test func armAtANonZeroTimeStartsSignalLossThere() {
    var machine = PTPStateMachine(config: .standard)
    machine.handle(.arm(.normal), at: .seconds(5))

    #expect(machine.tick(at: .milliseconds(14999)) == .armed)
    #expect(machine.tick(at: .milliseconds(15000)) == .alarm)
}
