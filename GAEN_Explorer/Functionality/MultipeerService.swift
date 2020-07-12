//
import Foundation
import MultipeerConnectivity
//  MultipeerService .swift
//  MultipeerConnectivityTest
//
//  Created by Bill on 6/20/20.
//  Copyright © 2020 NinjaMonkeyCoders. All rights reserved.
//
import SwiftUI

enum MultipeerExperimentMessageKind: String, Codable {
    case design
    case i_am_ready
    case startExperiment
    case leaveExperiment
}

struct MultipeerExperimentMessage: Codable {
    static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone.current
        return f
    }()

    let kind: MultipeerExperimentMessageKind

    // design
    let description: String?
    let durationMinutes: Int?

    // i_am_ready
    let key: PackagedKeys?
    let participants: Int?

    // startExperiment
    let startAtString: String?
    let endAtString: String?
    var startAt: Date? {
        guard let s = startAtString else { return nil }
        return MultipeerExperimentMessage.dateFormatter.date(from: s)
    }

    var endAt: Date? {
        guard let s = endAtString else { return nil }
        return MultipeerExperimentMessage.dateFormatter.date(from: s)
    }

    init(designDescription: String, durationMinutes: Int) {
        self.kind = .design
        self.description = designDescription
        self.durationMinutes = durationMinutes

        // i_am_ready
        self.key = nil
        self.participants = nil

        // startExperiment
        self.startAtString = nil
        self.endAtString = nil
    }

    init(readyKeys: PackagedKeys, participants: Int) {
        self.kind = .i_am_ready
        self.key = readyKeys
        self.participants = participants
        self.description = nil
        self.durationMinutes = nil

        // startExperiment
        self.startAtString = nil
        self.endAtString = nil
    }

    init(startAt: Date, endAt: Date) {
        self.kind = .startExperiment
        self.startAtString = MultipeerExperimentMessage.dateFormatter.string(from: startAt)

        self.endAtString = MultipeerExperimentMessage.dateFormatter.string(from: endAt)
        print("Sending launch message \(startAtString), \(endAtString)")
        self.description = nil
        self.durationMinutes = nil

        // i_am_ready
        self.key = nil
        self.participants = nil
    }

    init(leave: String) {
        self.kind = .leaveExperiment
        self.description = leave
        self.durationMinutes = nil
        self.key = nil
        self.participants = nil
        self.startAtString = nil
        self.endAtString = nil
    }
}

enum MultipeerMode: String, CaseIterable {
    case off
    case joiner
    case host
}

class PeerState: Identifiable {
    let id: MCPeerID
    let keys: PackagedKeys?
    let participantsSeen: Int?
    init(_ peerID: MCPeerID, _ keys: PackagedKeys? = nil, _ participants: Int? = nil) {
        self.id = peerID
        self.keys = keys
        self.participantsSeen = participants
    }

    func color(_ service: MultipeerService) -> Color {
        let ready = isReady(expected: service.peers.count + 1)
        if ready {
            return .primary
        }
        return .gray
    }

    func isReady(expected: Int) -> Bool {
        guard keys != nil,
            let p = participantsSeen else { return false }
        return expected == p
    }

    var label: String {
        guard keys != nil,
            let p = participantsSeen else {
            return id.displayName
        }

        return "\(id.displayName)"
    }
}

class MultipeerService: NSObject, ObservableObject {
    @Published var peers: [MCPeerID: PeerState] = [:]
    var oldParticipantCount = 0
    var participantCount: Int {
        1 + peers.count
    }

    @Published var askToBecomeHost: Bool = false

    func printPeers() {
        print("\(peers.count) Peers:")
        for peerId in peers.keys {
            print("\(peerId.displayName)")
        }
    }

    @Published
    var mode: MultipeerMode = .off {
        didSet {
            print("Set mode \(mode)")
            switch mode {
            case .off:
                serviceAdvertiser.stopAdvertisingPeer()
                serviceBrowser.stopBrowsingForPeers()
                peers = [:]
                session?.disconnect()
                session = nil
            case .joiner:
                session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .required)
                session!.delegate = self

                serviceBrowser.stopBrowsingForPeers()
                serviceAdvertiser.startAdvertisingPeer()
            case .host:
                serviceAdvertiser.stopAdvertisingPeer()
                serviceBrowser.startBrowsingForPeers()
            }
        }
    }

    let framework: ExposureFramework
    private let gaenServiceType = "gaen-explorer"

    private let myPeerId = MCPeerID(displayName: UIDevice.current.name)
    private let serviceAdvertiser: MCNearbyServiceAdvertiser
    private let serviceBrowser: MCNearbyServiceBrowser

    var session: MCSession?

    init(_ framework: ExposureFramework) {
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: gaenServiceType)
        self.serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: gaenServiceType)
        self.framework = framework
        super.init()

        serviceAdvertiser.delegate = self

        serviceBrowser.delegate = self
        serviceAdvertiser.stopAdvertisingPeer()
        serviceBrowser.stopBrowsingForPeers()
    }

    deinit {
        self.mode = .off
    }

    var isReady: Bool {
        framework.exposureLogsErased && framework.keysAreCurrent
    }

    func findPeers() {
        mode = .joiner
    }

    func collectKeys() {
        LocalStore.shared.deleteAllExposures()
        peers.values.forEach { peerState in
            if let k = peerState.keys {
                LocalStore.shared.addKeysFromUser(k)
            } else {
                print("No keys available from \(peerState.label)")
            }
        }
    }

    @discardableResult func send(_ message: MultipeerExperimentMessage, _ peer: MCPeerID? = nil) -> Bool {
        do {
            let sendTo = peer != nil ? [peer!] : Array(peers.keys)
            if sendTo.isEmpty {
                return true
            }
            let encoded = try JSONEncoder().encode(message)
            print("sending \(message.kind.rawValue) to \(sendTo.map { $0.displayName })")
            try session!.send(encoded, toPeers: sendTo, with: .reliable)
            print("sent")
            return true
        } catch {
            print("\(error)")
            return false
        }
    }

    func leaveExperiment() {
        assert(mode == .joiner)
        let message = MultipeerExperimentMessage(leave: "leaving")
        send(message)
        mode = .off
    }

    @discardableResult func sendDesign(_ peer: MCPeerID? = nil) -> Bool {
        if mode != .host { return false }

        let message = MultipeerExperimentMessage(designDescription: LocalStore.shared.experimentDescription, durationMinutes: LocalStore.shared.experimentDurationMinutes)
        return send(message, peer)
    }

    @discardableResult func sendReady(_ peer: MCPeerID? = nil) -> Bool {
        guard isReady else { return false }
        let newPartipantCount = participantCount
        let message = MultipeerExperimentMessage(readyKeys: framework.keys!, participants: newPartipantCount)
        let countChanged = newPartipantCount != oldParticipantCount
        oldParticipantCount = newPartipantCount
        // if changed, send to everyone
        return send(message, countChanged ? nil : peer)
    }

    @discardableResult func sendStart() -> Bool {
        guard mode == .host,
            let starts = LocalStore.shared.experimentStart,
            let ends = LocalStore.shared.experimentEnd else {
            return false
        }
        let message = MultipeerExperimentMessage(startAt: starts, endAt: ends)
        let result = send(message)
        if result {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.send(message)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.mode = .off
                }
            }

        } else {
            print("send start failed")
        }
        return result
    }
}

extension MultipeerService: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        NSLog("%@", "didNotStartAdvertisingPeer: \(error)")
    }

    func advertiser(_: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext _: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        NSLog("%@", "didReceiveInvitationFromPeer \(peerID)")
        invitationHandler(true, session)
    }
}

extension MultipeerService: MCNearbyServiceBrowserDelegate {
    func browser(_: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        NSLog("%@", "didNotStartBrowsingForPeers: \(error)")
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo _: [String: String]?) {
        NSLog("%@", "foundPeer: \(peerID)")
        NSLog("%@", "invitePeer: \(peerID)")
        browser.invitePeer(peerID, to: session!, withContext: nil, timeout: 10)
        sendDesign(peerID)
    }

    func browser(_: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        NSLog("%@", "lostPeer: \(peerID)")
    }
}

extension MultipeerService: MCSessionDelegate {
    func session(_: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        NSLog("%@", "peer \(peerID) didChangeState: \(state.rawValue)")
        DispatchQueue.main.async {
            switch state {
            case .notConnected:
                self.peers.removeValue(forKey: peerID)
            case .connecting:
                print("Ignoring connecting for \(peerID.displayName)")
            case .connected:
                self.peers[peerID] = PeerState(peerID)
                if self.mode == .joiner {
                    self.askToBecomeHost = false
                }
                if self.isReady {
                    self.sendReady(peerID)
                }
            }
        }
    }

    func session(_: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        NSLog("%@", "didReceiveData: \(data)")
        DispatchQueue.main.async {
            do {
                let message = try JSONDecoder().decode(MultipeerExperimentMessage.self, from: data)
                switch message.kind {
                case .design:
                    LocalStore.shared.experimentDescription = message.description!
                    LocalStore.shared.experimentDurationMinutes = message.durationMinutes!
                case .leaveExperiment:
                    self.peers.removeValue(forKey: peerID)
                    print("Removing participant \(peerID)")

                case .i_am_ready:
                    self.peers[peerID] = PeerState(peerID, message.key, message.participants)

                case .startExperiment:
                    print("Got start Experiment")
                    print(" start: \(message.startAtString)")
                    print(" end: \(message.endAtString)")
                    LocalStore.shared.experimentStart = message.startAt!
                    LocalStore.shared.experimentEnd = message.endAt!
                    self.collectKeys()
                    LocalStore.shared.launchExperiment(self.framework)
                    self.mode = .off
                }
            } catch {
                print("\(error)")
            }
        }
    }

    func session(_: MCSession, didReceive _: InputStream, withName _: String, fromPeer _: MCPeerID) {
        NSLog("%@", "didReceiveStream")
    }

    func session(_: MCSession, didStartReceivingResourceWithName _: String, fromPeer _: MCPeerID, with _: Progress) {
        NSLog("%@", "didStartReceivingResourceWithName")
    }

    func session(_: MCSession, didFinishReceivingResourceWithName _: String, fromPeer _: MCPeerID, at _: URL?, withError _: Error?) {
        NSLog("%@", "didFinishReceivingResourceWithName")
    }
}
