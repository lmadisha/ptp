import CoreBluetooth
import Foundation
import Observation
import PTPCore

@MainActor
@Observable
final class HeartbeatReceiver: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private(set) var state = "waiting for phone ID"
    private(set) var lastBeat: Date?
    private(set) var counter: UInt32?
    /// Signal strength of the connection in dBm, read after each beat. Nil until the first read.
    private(set) var rssi: Int?
    /// Called on every beat with the latest signal strength.
    var onBeat: (@MainActor (Int?) -> Void)?

    private var manager: CBCentralManager?
    private var phone: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private var readTask: Task<Void, Never>?
    private var expectedID: Data?
    private var ignoredPhones: Set<UUID> = []
    private var rescanAfterDisconnect = false

    func expect(_ id: UUID) {
        let expectedID = Heartbeat.encodeID(id)
        guard self.expectedID != expectedID else { return }
        self.expectedID = expectedID
        ignoredPhones.removeAll()
        lastBeat = nil
        counter = nil
        rssi = nil

        guard let manager else {
            state = "starting…"
            self.manager = CBCentralManager(delegate: self, queue: .main)
            return
        }
        if manager.state == .poweredOn { restartScan(using: manager) }
    }

    private func clearCharacteristic() {
        readTask?.cancel()
        readTask = nil
        characteristic = nil
        rssi = nil  // a reading from the old connection says nothing about the next one
    }

    private func startReading() {
        readTask?.cancel()
        readTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let phone = self?.phone, let characteristic = self?.characteristic else { return }
                phone.readValue(for: characteristic)
                do {
                    try await Task.sleep(for: DetectionConfig.standard.heartbeatInterval)
                } catch {
                    return
                }
            }
        }
    }

    /// The phone is connected but isn't serving the heartbeat (its app isn't running). Dropping the
    /// connection reconnects at once, so wait first or the two steps spin.
    private func dropAfterDelay(_ phone: CBPeripheral) {
        Task { [weak self] in
            try? await Task.sleep(for: DetectionConfig.standard.linkRestartDelay)
            self?.manager?.cancelPeripheralConnection(phone)
        }
    }

    private func scan(using manager: CBCentralManager) {
        phone = nil
        rescanAfterDisconnect = false
        clearCharacteristic()
        if manager.isScanning { manager.stopScan() }
        state = "scanning"
        manager.scanForPeripherals(withServices: [Heartbeat.service])
    }

    private func restartScan(using manager: CBCentralManager) {
        guard let phone, phone.state != .disconnected else {
            scan(using: manager)
            return
        }
        clearCharacteristic()
        rescanAfterDisconnect = true
        state = "reconnecting"
        manager.cancelPeripheralConnection(phone)
    }

    // The manager delivers delegates on the main queue. Pass only IDs and values into the actor.
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let managerID = ObjectIdentifier(central)
        MainActor.assumeIsolated {
            guard let manager, ObjectIdentifier(manager) == managerID else { return }
            switch manager.state {
            case .poweredOn:
                scan(using: manager)
                return
            case .poweredOff:
                state = "Bluetooth off"
            case .unauthorized:
                state = "not allowed"
            case .unsupported:
                state = "Bluetooth unavailable"
            default:
                state = "starting…"
            }
            phone = nil
            rescanAfterDisconnect = false
            clearCharacteristic()
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any], rssi RSSI: NSNumber
    ) {
        let managerID = ObjectIdentifier(central)
        let phoneID = peripheral.identifier
        MainActor.assumeIsolated {
            guard let manager, ObjectIdentifier(manager) == managerID, manager.state == .poweredOn,
                phone == nil, !ignoredPhones.contains(phoneID),
                let peripheral = manager.retrievePeripherals(withIdentifiers: [phoneID]).first
            else { return }

            phone = peripheral
            peripheral.delegate = self
            manager.stopScan()
            state = "connecting"
            manager.connect(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let managerID = ObjectIdentifier(central)
        let phoneID = ObjectIdentifier(peripheral)
        MainActor.assumeIsolated {
            guard let manager, ObjectIdentifier(manager) == managerID, manager.state == .poweredOn,
                let phone, ObjectIdentifier(phone) == phoneID, !rescanAfterDisconnect
            else { return }
            state = "discovering"
            phone.discoverServices([Heartbeat.service])
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: (any Error)?
    ) {
        let managerID = ObjectIdentifier(central)
        let phoneID = ObjectIdentifier(peripheral)
        MainActor.assumeIsolated {
            guard let manager, ObjectIdentifier(manager) == managerID, manager.state == .poweredOn,
                let phone, ObjectIdentifier(phone) == phoneID
            else { return }
            if rescanAfterDisconnect {
                scan(using: manager)
                return
            }
            clearCharacteristic()
            state = "reconnecting"
            manager.connect(phone)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?
    ) {
        let managerID = ObjectIdentifier(central)
        let phoneID = ObjectIdentifier(peripheral)
        MainActor.assumeIsolated {
            guard let manager, ObjectIdentifier(manager) == managerID, manager.state == .poweredOn,
                let phone, ObjectIdentifier(phone) == phoneID
            else { return }
            scan(using: manager)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        let phoneID = ObjectIdentifier(peripheral)
        let succeeded = error == nil
        MainActor.assumeIsolated {
            guard let phone, ObjectIdentifier(phone) == phoneID, !rescanAfterDisconnect else { return }
            guard succeeded, let service = phone.services?.first(where: { $0.uuid == Heartbeat.service })
            else {
                dropAfterDelay(phone)
                return
            }
            phone.discoverCharacteristics([Heartbeat.characteristic], for: service)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: (any Error)?
    ) {
        let phoneID = ObjectIdentifier(peripheral)
        let serviceID = ObjectIdentifier(service)
        let succeeded = error == nil
        MainActor.assumeIsolated {
            guard let phone, ObjectIdentifier(phone) == phoneID, !rescanAfterDisconnect,
                let service = phone.services?.first(where: { ObjectIdentifier($0) == serviceID })
            else { return }
            guard succeeded,
                let characteristic = service.characteristics?.first(where: { $0.uuid == Heartbeat.characteristic }),
                characteristic.properties.contains(.read)
            else {
                dropAfterDelay(phone)
                return
            }
            self.characteristic = characteristic
            state = "reading"
            startReading()
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?
    ) {
        guard error == nil, let data = characteristic.value else { return }
        let phoneID = ObjectIdentifier(peripheral)
        let characteristicID = ObjectIdentifier(characteristic)
        let receivedAt = Date.now
        MainActor.assumeIsolated {
            guard let manager, manager.state == .poweredOn, let expectedID,
                let phone, ObjectIdentifier(phone) == phoneID,
                let characteristic = self.characteristic, ObjectIdentifier(characteristic) == characteristicID
            else { return }
            guard data.prefix(Heartbeat.idLength) == expectedID else {
                ignoredPhones.insert(phone.identifier)
                restartScan(using: manager)
                return
            }
            let counterBytes = data.dropFirst(Heartbeat.idLength)
            guard counterBytes.count == MemoryLayout<UInt32>.size else { return }
            counter = counterBytes.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
            lastBeat = receivedAt
            state = "receiving"
            onBeat?(rssi)
            phone.readRSSI()
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: (any Error)?) {
        let phoneID = ObjectIdentifier(peripheral)
        // A real reading is negative dBm. 127 is Core Bluetooth's "not available"; zero is no reading either.
        let value = error == nil && RSSI.intValue < 0 ? RSSI.intValue : nil
        MainActor.assumeIsolated {
            guard let phone, ObjectIdentifier(phone) == phoneID, characteristic != nil else { return }
            rssi = value
        }
    }
}
