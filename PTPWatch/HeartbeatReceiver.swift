import CoreBluetooth
import Foundation
import Observation

@MainActor
@Observable
final class HeartbeatReceiver: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    private(set) var state = "starting…"
    private(set) var lastBeat: Date?
    private(set) var counter: UInt32?

    private var manager: CBCentralManager?
    private var phone: CBPeripheral?
    private var characteristic: CBCharacteristic?

    func start() {
        guard manager == nil else { return }
        manager = CBCentralManager(delegate: self, queue: .main)
    }

    private func scan(using manager: CBCentralManager) {
        phone = nil
        characteristic = nil
        state = "scanning"
        manager.scanForPeripherals(withServices: [Heartbeat.service])
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
            characteristic = nil
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
                phone == nil, let peripheral = manager.retrievePeripherals(withIdentifiers: [phoneID]).first
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
                let phone, ObjectIdentifier(phone) == phoneID
            else { return }
            state = "subscribing"
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
            characteristic = nil
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
            guard let phone, ObjectIdentifier(phone) == phoneID else { return }
            guard succeeded, let service = phone.services?.first(where: { $0.uuid == Heartbeat.service })
            else {
                manager?.cancelPeripheralConnection(phone)
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
            guard let phone, ObjectIdentifier(phone) == phoneID,
                let service = phone.services?.first(where: { ObjectIdentifier($0) == serviceID })
            else { return }
            guard succeeded,
                let characteristic = service.characteristics?.first(where: { $0.uuid == Heartbeat.characteristic }),
                characteristic.properties.contains(.notify)
            else {
                manager?.cancelPeripheralConnection(phone)
                return
            }
            self.characteristic = characteristic
            phone.setNotifyValue(true, for: characteristic)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        let phoneID = ObjectIdentifier(peripheral)
        let characteristicID = ObjectIdentifier(characteristic)
        let subscribed = error == nil && characteristic.isNotifying
        MainActor.assumeIsolated {
            guard let phone, ObjectIdentifier(phone) == phoneID,
                let characteristic = self.characteristic, ObjectIdentifier(characteristic) == characteristicID
            else { return }
            if subscribed {
                state = "receiving"
            } else {
                manager?.cancelPeripheralConnection(phone)
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: (any Error)?
    ) {
        guard error == nil, let data = characteristic.value, data.count == MemoryLayout<UInt32>.size
        else { return }
        let phoneID = ObjectIdentifier(peripheral)
        let characteristicID = ObjectIdentifier(characteristic)
        let receivedAt = Date.now
        let value = data.withUnsafeBytes { UInt32(littleEndian: $0.loadUnaligned(as: UInt32.self)) }
        MainActor.assumeIsolated {
            guard let phone, ObjectIdentifier(phone) == phoneID,
                let characteristic = self.characteristic, ObjectIdentifier(characteristic) == characteristicID
            else { return }
            lastBeat = receivedAt
            counter = value
        }
    }
}
