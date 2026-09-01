import Combine
import CoreMIDI
import Foundation

final class MIDIInputService: ObservableObject {
    @Published private(set) var connectedSources: [MIDISource] = []
    @Published private(set) var lastEvent: MIDIInputEvent?
    @Published private(set) var systemSourceCount: Int = 0
    @Published private(set) var diagnosticMessages: [String] = []

    var onEvent: ((MIDIInputEvent) -> Void)?

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var connectedEndpointIDs: Set<Int> = []
    private let eventQueue = DispatchQueue(label: "SightlinkPiano.MIDIInputService.events")

    var isConnected: Bool {
        !connectedSources.isEmpty
    }

    init() {
        log("MIDIInputService init")
        createClient()
        createInputPort()
        refreshSources()
    }

    deinit {
        disconnectAllSources()

        if inputPort != 0 {
            MIDIPortDispose(inputPort)
        }

        if client != 0 {
            MIDIClientDispose(client)
        }
    }

    func refreshSources() {
        log("refreshSources() begin")
        let sourceCountBeforeRefresh = MIDIGetNumberOfSources()
        log("source count before refresh: \(sourceCountBeforeRefresh)")

        let sources = currentSystemSources()
        let sourceIDs = Set(sources.map(\.id))

        let disconnectedEndpointIDs = connectedEndpointIDs.filter { !sourceIDs.contains($0) }
        for endpointID in disconnectedEndpointIDs {
            if let endpoint = endpoint(for: endpointID) {
                let status = MIDIPortDisconnectSource(inputPort, endpoint)
                logOSStatus(status, context: "disconnect removed source \(endpointID)")
            }
            connectedEndpointIDs.remove(endpointID)
        }

        if inputPort == 0 {
            log("input port unavailable; skipping source connections")
        } else {
            for source in sources where !connectedEndpointIDs.contains(source.id) {
                if let endpoint = endpoint(for: source.id) {
                    let status = MIDIPortConnectSource(inputPort, endpoint, nil)
                    logOSStatus(status, context: "connect source \(source.name) (\(source.id))")

                    if status == noErr {
                        connectedEndpointIDs.insert(source.id)
                    }
                }
            }
        }

        let sourceCountAfterRefresh = MIDIGetNumberOfSources()
        log("source count after refresh: \(sourceCountAfterRefresh)")

        DispatchQueue.main.async { [weak self] in
            self?.connectedSources = sources
            self?.systemSourceCount = sourceCountAfterRefresh
        }
    }

    func isConnected(to source: MIDISource) -> Bool {
        connectedEndpointIDs.contains(source.id)
    }

    private func createClient() {
        let status = MIDIClientCreateWithBlock("Sightlink Piano MIDI Client" as CFString, &client) { [weak self] notification in
            self?.log("CoreMIDI setup/device-change notification: \(notification.pointee.messageID.rawValue)")
            self?.eventQueue.async {
                self?.refreshSources()
            }
        }

        logOSStatus(status, context: "create MIDI client")

        if status != noErr {
            client = 0
        }
    }

    private func createInputPort() {
        guard client != 0 else {
            return
        }

        let status = MIDIInputPortCreateWithBlock(
            client,
            "Sightlink Piano MIDI Input" as CFString,
            &inputPort
        ) { [weak self] packetList, _ in
            self?.handle(packetList: packetList)
        }

        logOSStatus(status, context: "create legacy MIDI 1.0 input port")

        if status != noErr {
            inputPort = 0
        }
    }

    private func handle(packetList: UnsafePointer<MIDIPacketList>) {
        var packet = packetList.pointee.packet

        for _ in 0..<packetList.pointee.numPackets {
            let bytes = withUnsafePointer(to: &packet.data.0) { pointer in
                UnsafeBufferPointer(start: pointer, count: Int(packet.length))
            }

            if bytes.count >= 3,
               let event = MIDIMessageDecoder.decodeMIDI1ChannelVoice(
                status: bytes[0],
                data1: bytes[1],
                data2: bytes[2]
               ) {
                publish(event)
            }

            packet = MIDIPacketNext(&packet).pointee
        }
    }

    private func publish(_ event: MIDIInputEvent) {
        DispatchQueue.main.async { [weak self] in
            self?.lastEvent = event
            self?.onEvent?(event)
        }
    }

    private func disconnectAllSources() {
        for endpointID in connectedEndpointIDs {
            if let endpoint = endpoint(for: endpointID) {
                let status = MIDIPortDisconnectSource(inputPort, endpoint)
                logOSStatus(status, context: "disconnect source \(endpointID)")
            }
        }

        connectedEndpointIDs.removeAll()
    }

    private func currentSystemSources() -> [MIDISource] {
        (0..<MIDIGetNumberOfSources()).compactMap { index in
            let endpoint = MIDIGetSource(index)
            guard endpoint != 0 else {
                log("source[\(index)]: empty endpoint")
                return nil
            }

            let source = MIDISource(id: Int(endpoint), name: displayName(for: endpoint))
            log("source[\(index)]: \(source.name), endpoint \(source.id)")
            return source
        }
    }

    private func endpoint(for id: Int) -> MIDIEndpointRef? {
        for index in 0..<MIDIGetNumberOfSources() {
            let endpoint = MIDIGetSource(index)
            if Int(endpoint) == id {
                return endpoint
            }
        }

        return nil
    }

    private func displayName(for endpoint: MIDIEndpointRef) -> String {
        var unmanagedName: Unmanaged<CFString>?
        let status = MIDIObjectGetStringProperty(endpoint, kMIDIPropertyDisplayName, &unmanagedName)

        guard status == noErr, let name = unmanagedName?.takeRetainedValue() as String? else {
            return "MIDI Source \(Int(endpoint))"
        }

        return name
    }

    private func logOSStatus(_ status: OSStatus, context: String) {
        log("\(context): OSStatus \(status)")
    }

    private func log(_ message: String) {
        let formattedMessage = "[MIDI Debug] \(message)"
        print(formattedMessage)

        DispatchQueue.main.async { [weak self] in
            self?.diagnosticMessages.append(formattedMessage)
        }
    }
}
