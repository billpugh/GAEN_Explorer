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
}

struct MultipeerExperimentMessage: Codable {
    static let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.timeZone = TimeZone.current
        f.formatOptions = .withTime
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
        self.endAtString = ISO8601DateFormatter.string(from: endAt, timeZone: TimeZone.current, formatOptions: .withFullTime)
        self.description = nil
        self.durationMinutes = nil

        // i_am_ready
        self.key = nil
        self.participants = nil
    }
}

enum MultipeerMode: String, CaseIterable {
    case off
    case joiner
    case host
}

class PeerState {
    let peerID: MCPeerID
    let keys: PackagedKeys?
    let participantsSeen: Int?
    init(_ peerID: MCPeerID, _ keys: PackagedKeys? = nil, _ participants: Int? = nil) {
        self.peerID = peerID
        self.keys = keys
        self.participantsSeen = participants
    }
}

class MultipeerService: NSObject, ObservableObject {
    @Published var peers: [MCPeerID: PeerState] = [:]
    func printPeers() {
        print("\(peers.count) Peers:")
        for peerId in peers.keys {
            print("\(peerId.displayName)")
        }
    }

    @Published
    var mode: MultipeerMode = .joiner {
        didSet {
            print("Set mode \(mode)")
            switch mode {
            case .off:
                serviceAdvertiser.stopAdvertisingPeer()
                serviceBrowser.stopBrowsingForPeers()
            case .joiner:
                serviceBrowser.stopBrowsingForPeers()
                serviceAdvertiser.startAdvertisingPeer()
            case .host:
                serviceAdvertiser.stopAdvertisingPeer()
                serviceBrowser.startBrowsingForPeers()
            }
        }
    }

    private let gaenServiceType = "gaen-explorer"

    private let myPeerId = MCPeerID(displayName: UIDevice.current.name)
    private let serviceAdvertiser: MCNearbyServiceAdvertiser
    private let serviceBrowser: MCNearbyServiceBrowser

    lazy var session: MCSession = {
        let session = MCSession(peer: self.myPeerId, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        return session
    }()

    override init() {
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerId, discoveryInfo: nil, serviceType: gaenServiceType)
        self.serviceBrowser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: gaenServiceType)
        super.init()

        serviceAdvertiser.delegate = self
        serviceAdvertiser.startAdvertisingPeer()

        serviceBrowser.delegate = self
    }

    deinit {
        self.mode = .off
    }

    func send(_ message: MultipeerExperimentMessage, _ peer: MCPeerID? = nil) -> Bool {
        do {
            let sendTo = peer != nil ? [peer!] : Array(peers.keys)
            let encoded = try JSONEncoder().encode(message)
            try session.send(encoded, toPeers: sendTo, with: .reliable)
            return true
        } catch {
            print("\(error)")
            return false
        }
    }

    func sendDesign(_ peer: MCPeerID? = nil) -> Bool {
        if mode != .host { return false }
        if LocalStore.shared.experimentDescription.isEmpty { return false }

        let message = MultipeerExperimentMessage(designDescription: LocalStore.shared.experimentDescription, durationMinutes: LocalStore.shared.experimentDurationMinutes)
        return send(message, peer)
    }

    func sendReady(_ peer: MCPeerID? = nil) -> Bool {
        guard ExposureFramework.shared.exposureLogsErased,
            let keys = ExposureFramework.shared.package else { return false }

        let message = MultipeerExperimentMessage(readyKeys: keys, participants: 1 + peers.count)
        return send(message, peer)
    }

    func sendStart() -> Bool {
        guard mode == .host,
            let starts = LocalStore.shared.experimentStart,
            let ends = LocalStore.shared.experimentEnd else {
            return false
        }
        let message = MultipeerExperimentMessage(startAt: starts, endAt: ends)
        return send(message)
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
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
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
            }
        }
    }

    func session(_: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        NSLog("%@", "didReceiveData: \(data)")
        do {
            let message = try JSONDecoder().decode(MultipeerExperimentMessage.self, from: data)
            switch message.kind {
            case .design:
                LocalStore.shared.experimentDescription = message.description!
                LocalStore.shared.experimentDurationMinutes = message.durationMinutes!

            case .i_am_ready:
                peers[peerID] = PeerState(peerID, message.key, message.participants)
                
            case .startExperiment:
                LocalStore.shared.experimentStart = message.startAt
                LocalStore.shared.experimentEnd = message.endAt
            }
        } catch {
            print("\(error)")
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
