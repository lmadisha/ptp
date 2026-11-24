import Foundation
@testable import PTPStore
import Testing

private let day: TimeInterval = 86_400
private let start = Date(timeIntervalSince1970: 1_800_057_600)

@Test func placeAreaFloorsCoordinatesToTheGrid() {
    #expect(PlaceStore.area(latitude: -0.0001, longitude: 0.0026) == "-1:1")
    #expect(PlaceStore.area(latitude: -0.0024, longitude: 0.0049) == "-1:1")
    #expect(PlaceStore.area(latitude: -0.0026, longitude: 0.0051) == "-2:2")

    var config = StoreConfig.standard
    config.placeGridDegrees = 0.01
    #expect(PlaceStore.area(latitude: -0.0026, longitude: 0.0051, config: config) == "-1:0")
}

@Test func visitArrivalIsRoundedDownToTheStartOfItsUTCDay() throws {
    let path = temporaryPlacePath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let arrival = Date(timeIntervalSince1970: -1)
    let store = try PlaceStore(path: path, now: arrival)
    try store.recordVisit(area: "0:0", at: arrival)

    let database = try Database(path: path)
    #expect(try database.run("SELECT area, visited_day FROM place_visit") == [[.text("0:0"), .real(-day)]])
}

@Test func visitsAreCountedByAreaWithinTheRetentionBoundary() throws {
    let store = try PlaceStore(path: ":memory:", now: start)
    try store.recordVisit(area: "0:0", at: start)
    try store.recordVisit(area: "0:0", at: start + day)
    try store.recordVisit(area: "1:0", at: start + day)

    #expect(try store.visitCount(area: "0:0", now: start + 60 * day) == 2)
    #expect(try store.visitCount(area: "0:0", now: start + 60 * day + 1) == 1)
    #expect(try store.visitCount(area: "1:0", now: start + 60 * day + 1) == 1)

    try store.recordVisit(area: "2:0", at: start + 61 * day + 1)
    #expect(try store.areaCount() == 1)
}

@Test func visitsTooFarInTheFutureAreExcludedAndPruned() throws {
    let store = try PlaceStore(path: ":memory:", now: start)
    try store.recordVisit(area: "0:0", at: start + 60 * day)
    try store.recordVisit(area: "1:0", at: start + 61 * day)

    #expect(try store.visitCount(area: "0:0", now: start) == 1)
    #expect(try store.visitCount(area: "1:0", now: start) == 0)
    try store.recordVisit(area: "2:0", at: start)
    #expect(try store.areaCount() == 2)
}

@Test func aRepeatedReportForTheSameAreaAndDayCountsOnce() throws {
    let store = try PlaceStore(path: ":memory:", now: start)
    // Arrival, then the same visit again at departure, then a second visit later that day.
    try store.recordVisit(area: "0:0", at: start + 100)
    try store.recordVisit(area: "0:0", at: start + 100)
    try store.recordVisit(area: "0:0", at: start + 5_000)
    try store.recordVisit(area: "1:0", at: start + 100)
    #expect(try store.visitCount(area: "0:0", now: start + day) == 1)
    #expect(try store.visitCount(area: "1:0", now: start + day) == 1)
}

@Test func deletingLearnedPlacesClearsEveryArea() throws {
    let store = try PlaceStore(path: ":memory:", now: start)
    try store.recordVisit(area: "0:0", at: start)
    try store.recordVisit(area: "0:0", at: start)
    try store.recordVisit(area: "1:0", at: start)
    #expect(try store.areaCount() == 2)

    try store.deleteAll()
    #expect(try store.areaCount() == 0)
    #expect(try store.visitCount(area: "0:0", now: start) == 0)
}

@Test func placeTextIsStoredAsData() throws {
    let store = try PlaceStore(path: ":memory:", now: start)
    let area = "x'); DROP TABLE place_visit; --"
    try store.recordVisit(area: area, at: start)
    #expect(try store.visitCount(area: area, now: start) == 1)
}

@Test func reopeningAPlaceStoreKeepsRecentVisitsAndPrunesExpiredOnes() throws {
    let path = temporaryPlacePath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    do {
        let store = try PlaceStore(path: path, now: start)
        try store.recordVisit(area: "0:0", at: start)
        try store.recordVisit(area: "1:0", at: start + day)
    }

    let now = start + 60 * day + 1
    let reopened = try PlaceStore(path: path, now: now)
    #expect(try reopened.areaCount() == 1)
    #expect(try reopened.visitCount(area: "1:0", now: now) == 1)
}

private func temporaryPlacePath() -> String {
    FileManager.default.temporaryDirectory.appending(path: "ptp-places-\(UUID().uuidString).sqlite").path
}
