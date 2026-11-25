import Foundation
@testable import PTPStore
import Testing

@Test func chosenPlaceCoordinatesAreRoundedBeforeStorage() throws {
    let path = temporaryChosenPlacePath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let store = try ChosenPlaceStore(path: path)
    let place = try store.add(.risky, latitude: -0.1236, longitude: 0.4564)

    #expect(place.latitude == -0.124)
    #expect(place.longitude == 0.456)
    let database = try Database(path: path)
    #expect(try database.run("SELECT latitude, longitude FROM chosen_place") == [[.real(-0.124), .real(0.456)]])
}

@Test func chosenPlacesRespectTheConfiguredCap() throws {
    var config = StoreConfig.standard
    config.maxChosenPlaces = 1
    let store = try ChosenPlaceStore(path: ":memory:", config: config)
    let place = try store.add(.safe, latitude: 0, longitude: 0)
    #expect(throws: StoreError.self) {
        try store.add(.risky, latitude: 0.01, longitude: 0)
    }
    #expect(try store.places() == [place])
}

@Test func chosenPlaceKindsRoundTripInIDOrderAndCanBeDeleted() throws {
    let store = try ChosenPlaceStore(path: ":memory:")
    let risky = try store.add(.risky, latitude: 0, longitude: 0)
    let safe = try store.add(.safe, latitude: 0.01, longitude: 0)

    #expect(risky.kind == .risky)
    #expect(safe.kind == .safe)
    #expect(risky.id < safe.id)
    #expect(try store.places() == [risky, safe])
    try store.deleteAll()
    #expect(try store.places().isEmpty)
}

@Test func chosenPlaceKindIsStoredAsText() throws {
    let path = temporaryChosenPlacePath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let store = try ChosenPlaceStore(path: path)
    try store.add(.risky, latitude: 0, longitude: 0)
    try store.add(.safe, latitude: 0.01, longitude: 0)

    let database = try Database(path: path)
    #expect(try database.run("SELECT kind, typeof(kind) FROM chosen_place ORDER BY id") ==
        [[.text("risky"), .text("text")], [.text("safe"), .text("text")]])
}

@Test func reopeningAChosenPlaceStoreKeepsPlaces() throws {
    let path = temporaryChosenPlacePath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let place: ChosenPlace
    do {
        let store = try ChosenPlaceStore(path: path)
        place = try store.add(.risky, latitude: 0, longitude: 0)
    }

    let reopened = try ChosenPlaceStore(path: path)
    #expect(try reopened.places() == [place])
}

@Test func chosenPlaceContainmentUsesTheRadiusAndReturnsTheFirstMatch() throws {
    let store = try ChosenPlaceStore(path: ":memory:")
    let first = try store.add(.risky, latitude: 0, longitude: 0)
    try store.add(.safe, latitude: 0.01, longitude: 0)

    #expect(try store.place(containingLatitude: 0.001, longitude: 0) == first)
    #expect(try store.place(containingLatitude: 0.003, longitude: 0) == nil)
}

@Test func markingASpotAgainReplacesTheEarlierMarkingNearby() throws {
    let store = try ChosenPlaceStore(path: ":memory:")
    let far = try store.add(.risky, latitude: 0.01, longitude: 0)
    try store.add(.risky, latitude: 0, longitude: 0)
    // 111 m away: inside the 150 m radius, so the risky place there becomes this safe one.
    let safe = try store.add(.safe, latitude: 0.001, longitude: 0)
    #expect(try store.places() == [far, safe])
}

@Test func aRefusedMarkingKeepsTheOneItWouldHaveReplaced() throws {
    let path = temporaryChosenPlacePath()
    defer { try? FileManager.default.removeItem(atPath: path) }
    let kept = try ChosenPlaceStore(path: path).add(.risky, latitude: 0, longitude: 0)
    // With room for none, the nearby delete runs and then the insert is refused: both must roll back.
    var config = StoreConfig.standard
    config.maxChosenPlaces = 0
    let full = try ChosenPlaceStore(path: path, config: config)
    #expect(throws: StoreError.self) { try full.add(.safe, latitude: 0.001, longitude: 0) }
    #expect(try full.places() == [kept])
}

private func temporaryChosenPlacePath() -> String {
    FileManager.default.temporaryDirectory.appending(path: "ptp-chosen-places-\(UUID().uuidString).sqlite").path
}
