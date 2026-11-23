import CoreBluetooth
import Foundation
import Observation
import PTPCore

@MainActor
@Observable
final class HeartbeatSender: NSObject, CBPeripheralManagerDelegate {
    private(set) var state = "Heartbeat: starting…"

    private var manager: CBPeripheralManager?
    private var service: CBMutableService?
    private var characteristic: CBMutableCharacteristic?
    private var sendTask: Task<Void, Never>?
    private var counter: UInt32 = 0

    func start() {
        guard manager == nil else { return }
        manager = CBPeripheralManager(delegate: self, queue: .main)
    }

    private func addService(using manager: CBPeripheralManager) {
        guard service == nil else { return }
        // The local service database can survive a Bluetooth power cycle.
        manager.stopAdvertising()
        manager.removeAllServices()
        let characteristic = CBMutableCharacteristic(
            type: Heartbeat.characteristic, properties: .notify, value: nil, permissions: [])
        let service = CBMutableService(type: Heartbeat.service, primary: true)
        service.characteristics = [characteristic]
        self.characteristic = characteristic
        self.service = service
        manager.add(service)
    }

    private func startSending() {
        guard sendTask == nil else { return }
        state = "Heartbeat: sending"
        sendTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: DetectionConfig.standard.heartbeatInterval)
                } catch {
                    return
                }
                guard !Task.isCancelled, let self else { return }
                sendBeat()
            }
        }
    }

    private func stopSending() {
        sendTask?.cancel()
        sendTask = nil
    }

    private func sendBeat() {
        guard let manager, manager.state == .poweredOn, let characteristic else { return }
        var payload = counter.littleEndian
        let data = withUnsafeBytes(of: &payload) { Data($0) }

        if manager.updateValue(data, for: characteristic, onSubscribedCentrals: nil) {
            counter &+= 1
        }
    }

    // The manager delivers delegates on the main queue. Pass only IDs and values into the actor.
    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        let managerID = ObjectIdentifier(peripheral)
        MainActor.assumeIsolated {
            guard let manager, ObjectIdentifier(manager) == managerID else { return }
            if manager.state == .poweredOn {
                addService(using: manager)
                return
            }

            stopSending()
            service = nil
            characteristic = nil
            switch manager.state {
            case .poweredOff:
                state = "Heartbeat: Bluetooth off"
            case .unauthorized:
                state = "Heartbeat: not allowed"
            case .unsupported:
                state = "Heartbeat: Bluetooth unavailable"
            default:
                state = "Heartbeat: starting…"
            }
        }
    }

    nonisolated func peripheralManager(
        _ peripheral: CBPeripheralManager, didAdd service: CBService, error: (any Error)?
    ) {
        let managerID = ObjectIdentifier(peripheral)
        let serviceID = ObjectIdentifier(service)
        let succeeded = error == nil
        MainActor.assumeIsolated {
            guard let manager, ObjectIdentifier(manager) == managerID, manager.state == .poweredOn,
                let service = self.service, ObjectIdentifier(service) == serviceID
            else { return }
            guard succeeded else {
                state = "Heartbeat: could not add service"
                return
            }
            manager.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [Heartbeat.service]])
        }
    }

    nonisolated func peripheralManagerDidStartAdvertising(
        _ peripheral: CBPeripheralManager, error: (any Error)?
    ) {
        let managerID = ObjectIdentifier(peripheral)
        let succeeded = error == nil
        MainActor.assumeIsolated {
            guard let manager, ObjectIdentifier(manager) == managerID, manager.state == .poweredOn,
                sendTask == nil
            else { return }
            state = succeeded ? "Heartbeat: advertising" : "Heartbeat: could not advertise"
        }
    }

    nonisolated func peripheralManager(
        _ peripheral: CBPeripheralManager, central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        updateSubscription(
            managerID: ObjectIdentifier(peripheral), characteristicID: ObjectIdentifier(characteristic))
    }

    nonisolated func peripheralManager(
        _ peripheral: CBPeripheralManager, central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        updateSubscription(
            managerID: ObjectIdentifier(peripheral), characteristicID: ObjectIdentifier(characteristic))
    }

    private nonisolated func updateSubscription(
        managerID: ObjectIdentifier, characteristicID: ObjectIdentifier
    ) {
        MainActor.assumeIsolated {
            guard let manager, ObjectIdentifier(manager) == managerID, manager.state == .poweredOn,
                let characteristic, ObjectIdentifier(characteristic) == characteristicID
            else { return }
            if characteristic.subscribedCentrals?.isEmpty == false {
                startSending()
            } else {
                stopSending()
                state = "Heartbeat: advertising"
            }
        }
    }
}
