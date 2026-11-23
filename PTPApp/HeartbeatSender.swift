import CoreBluetooth
import Foundation
import Observation

@MainActor
@Observable
final class HeartbeatSender: NSObject, CBPeripheralManagerDelegate {
    private(set) var state = "Heartbeat: starting…"
    var onBeat: (@MainActor () -> Void)?

    private var manager: CBPeripheralManager?
    private var service: CBMutableService?
    private var characteristic: CBMutableCharacteristic?
    private let sessionIDBytes: Data
    private var counter: UInt32 = 0

    init(sessionID: UUID) {
        sessionIDBytes = Heartbeat.encodeID(sessionID)
    }

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
            type: Heartbeat.characteristic, properties: .read, value: nil, permissions: .readable)
        let service = CBMutableService(type: Heartbeat.service, primary: true)
        service.characteristics = [characteristic]
        self.characteristic = characteristic
        self.service = service
        manager.add(service)
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
                state != "Heartbeat: answering"
            else { return }
            state = succeeded ? "Heartbeat: advertising" : "Heartbeat: could not advertise"
        }
    }

    nonisolated func peripheralManager(
        _ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest
    ) {
        let managerID = ObjectIdentifier(peripheral)
        let characteristicID = ObjectIdentifier(request.characteristic)
        let offset = request.offset
        let (value, result): (Data?, CBATTError.Code) = MainActor.assumeIsolated {
            guard let manager, ObjectIdentifier(manager) == managerID, manager.state == .poweredOn,
                let characteristic, ObjectIdentifier(characteristic) == characteristicID
            else { return (nil, .attributeNotFound) }

            var payload = sessionIDBytes
            withUnsafeBytes(of: counter.littleEndian) { payload.append(contentsOf: $0) }
            guard offset <= payload.count else { return (nil, .invalidOffset) }

            counter &+= 1
            state = "Heartbeat: answering"
            return (payload.dropFirst(offset), .success)
        }
        if let value { request.value = value }
        peripheral.respond(to: request, withResult: result)
        if result == .success {
            MainActor.assumeIsolated { onBeat?() }
        }
    }
}
