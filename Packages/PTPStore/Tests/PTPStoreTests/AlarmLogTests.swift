import Foundation
@testable import PTPStore
import Testing

private let start = Date(timeIntervalSince1970: 1_800_000_000)
private let day: TimeInterval = 24 * 60 * 60

@Test func standardRetentionIsThirtyDays() {
    #expect(StoreConfig.standard.alarmLogRetention == .seconds(30 * 24 * 60 * 60))
}

@Test func eventsComeBackNewestFirst() throws {
    let log = try AlarmLog(path: ":memory:", now: start)
    try log.record("alarm", at: start)
    try log.record("acknowledged", at: start + 5)
    #expect(
        try log.events() == [
            AlarmEvent(time: start + 5, kind: "acknowledged"),
            AlarmEvent(time: start, kind: "alarm"),
        ])
}

@Test func aNewLogIsEmpty() throws {
    #expect(try AlarmLog(path: ":memory:", now: start).events().isEmpty)
}

@Test func recordingDeletesEventsOlderThanTheRetention() throws {
    let log = try AlarmLog(path: ":memory:", now: start)
    try log.record("alarm", at: start)
    try log.record("alarm", at: start + 1)
    // Exactly 30 days later the first event is on the boundary and stays.
    try log.record("alarm", at: start + 30 * day)
    #expect(try log.events().count == 3)
    // One second later the first has expired; the second is now on the boundary.
    try log.record("alarm", at: start + 30 * day + 1)
    #expect(try log.events().map(\.time) == [start + 30 * day + 1, start + 30 * day, start + 1])
}

@Test func retentionComesFromTheConfig() throws {
    let log = try AlarmLog(path: ":memory:", config: StoreConfig(alarmLogRetention: .seconds(10)), now: start)
    try log.record("alarm", at: start)
    try log.record("alarm", at: start + 11)
    #expect(try log.events().count == 1)
}

@Test func textIsStoredAsDataNotAsSQL() throws {
    let log = try AlarmLog(path: ":memory:", now: start)
    let kind = "x'); DROP TABLE alarm_event; --"
    try log.record(kind, at: start)
    #expect(try log.events() == [AlarmEvent(time: start, kind: kind)])
}

@Test func reopeningAFileKeepsEventsAndDeletesExpiredOnes() throws {
    let path = FileManager.default.temporaryDirectory.appending(path: "ptpstore-\(UUID().uuidString).sqlite").path
    defer { try? FileManager.default.removeItem(atPath: path) }

    do {
        let log = try AlarmLog(path: path, now: start)
        try log.record("alarm", at: start)
        try log.record("alarm", at: start + 10 * day)
    }
    // Reopening must not run the schema step again, and it deletes what expired meanwhile.
    let reopened = try AlarmLog(path: path, now: start + 35 * day)
    #expect(try reopened.events() == [AlarmEvent(time: start + 10 * day, kind: "alarm")])
}

@Test func anUnopenablePathThrows() {
    #expect(throws: StoreError.self) {
        try AlarmLog(path: "/nonexistent-directory/ptp.sqlite", now: start)
    }
}

private func temporaryPath() -> String {
    FileManager.default.temporaryDirectory.appending(path: "ptpstore-\(UUID().uuidString).sqlite").path
}

@Test func aSchemaStepInterruptedBeforeTheVersionWasWrittenStillOpens() throws {
    let path = temporaryPath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    do {
        let database = try Database(path: path)
        try database.run(
            "CREATE TABLE alarm_event (id INTEGER PRIMARY KEY, created_at REAL NOT NULL, kind TEXT NOT NULL)")
    }
    let log = try AlarmLog(path: path, now: start)
    try log.record("alarm", at: start)
    #expect(try log.events().count == 1)
}

@Test func aDatabaseFromANewerVersionIsRefused() throws {
    let path = temporaryPath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    do {
        let database = try Database(path: path)
        try database.run("PRAGMA user_version = 2")
    }
    #expect(throws: StoreError.self) { try AlarmLog(path: path, now: start) }
}

@Test func eventsDatedFarInTheFutureAreDeleted() throws {
    let log = try AlarmLog(path: ":memory:", now: start)
    try log.record("alarm", at: start + 365 * day)  // a wrong device clock
    try log.record("alarm", at: start)
    #expect(try log.events() == [AlarmEvent(time: start, kind: "alarm")])
}

@Test func aSecondStatementInOneCallIsRefused() throws {
    let database = try Database(path: ":memory:")
    #expect(throws: StoreError.self) { try database.run("CREATE TABLE a (x); CREATE TABLE b (x)") }
}
