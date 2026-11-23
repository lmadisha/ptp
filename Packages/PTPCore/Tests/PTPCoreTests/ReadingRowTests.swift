import PTPCore
import Testing

@Test func readingRowUsesExpectedCSVColumns() {
    #expect(ReadingRow.csvHeader == "t_ms,distance_m,source,app_state,battery_pct")
}

@Test func readingRowFormatsDistanceToTwoDecimalPlaces() {
    let row = ReadingRow(
        tMs: 1_700_000_000_123, distanceMeters: 2.5, source: .uwb,
        appState: "active", batteryPercent: 87)

    #expect(row.csvLine == "1700000000123,2.50,uwb,active,87")
}

@Test func readingRowLeavesMissingDistanceAndBatteryBlank() {
    let row = ReadingRow(
        tMs: 1_700_000_000_456, distanceMeters: nil, source: .ble,
        appState: "background", batteryPercent: nil)

    #expect(row.csvLine == "1700000000456,,ble,background,")
}
