//
//  ExperimentSetupView.swift
//  GAEN_Explorer
//
//  Created by Bill on 6/20/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import SwiftUI

var experimentRunningTimer: Timer?

struct MultipeerExperimentView: View {
    let formatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        // formatter.includesApproximationPhrase = true
        formatter.includesTimeRemainingPhrase = true
        formatter.allowedUnits = [.minute, .second]
        return formatter
    }()

    @EnvironmentObject var localStore: LocalStore
    @EnvironmentObject var framework: ExposureFramework
    @EnvironmentObject var multipeerService: MultipeerService
    @State var description: String = ""
    @State var duration: Int = 27
    @State var experimentRunning: Bool = false
    @State var showingAlert: Bool = false
    @State var actionHeader: String = "Actions needed"
    var timer: Timer?
    @State var started: Bool = false
    @State var declinedHost: Bool = false
    @State var haveKeys: Bool = false
    @State var becomeActiveObserver: NSObjectProtocol? = nil

    func askHost() {
        guard !declinedHost, multipeerService.mode != .host, framework.exposureLogsErased, multipeerService.peers.isEmpty else { return }
        showingAlert = true
    }

    func updateView() {
        withAnimation {
            askHost()
            haveKeys = framework.keysAreCurrent
            self.multipeerService.mightBeReady()
        }
    }

    @State var remaining: String = "Not started"

    func startExperiment() {}

    var body: some View {
        Form {
            Section(header: Text("Experiment parameters").font(.title)) {
                HStack {
                    Text("Description:").font(.headline)
                    TextField("description", text: self.$localStore.experimentDescription, onCommit: { self.multipeerService.sendDesign() })
                }
                Stepper(value: self.$localStore.experimentDurationMinutes, in: 9 ... 59, step: 5, onEditingChanged: { b in print("onEditingChanged \(b) \(self.localStore.experimentDurationMinutes)")
                    if !b {
                        self.multipeerService.sendDesign()
                    }
                }) {
                    Text("Duration \(self.localStore.experimentDurationMinutes) minutes")
                }

                HStack(spacing: 10) {
                    Text("mode: \(multipeerService.mode.rawValue)")
                    Text("\(framework.exposureLogsErased ? "erased" : "not erased")")
                    Text("peers: \(multipeerService.peers.count)")
                    Button(action: { self.multipeerService.sendDesign() }) { Text("Send design") }
                }
            }.disabled(multipeerService.mode != .host)
            if experimentRunning {
                Section(header: Text(started ? "Experiment running" : "Getting ready to start").font(.title)) {
                    Text(remaining)
                    Text("Experiment ends at \(timeFormatter.string(from: localStore.experimentEnd!))")
                    Text("User: \(self.localStore.userName)")
                }.font(.headline).padding().navigationBarTitle("Multipeer experiment running", displayMode: .inline)
                    .onAppear {
                        experimentRunningTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                            let remaining = Date().distance(to: self.started ? self.localStore.experimentEnd! : self.localStore.experimentStart!)
                            print("Remaining time: \(remaining)")
                            if remaining <= 0 {
                                if self.started {
                                    self.remaining = "Done"
                                    timer.invalidate()
                                    experimentRunningTimer = nil
                                } else {
                                    self.remaining = "Starting"
                                    self.started = true
                                }
                            } else {
                                self.remaining = self.formatter.string(from: remaining) ?? "--"
                            }
                        }
                    }.onDisappear {
                        experimentRunningTimer?.invalidate()
                        experimentRunningTimer = nil
                    }
            } else {
                Section(header: Text(actionHeader).font(.title)) {
                    Button(action: {
                        self.framework.currentKeys(localStore.userName) { _ in
                            self.framework.currentKeys(localStore.userName) {
                                _ in
                                print("after calling currentKeys, \(self.framework.keysAreCurrent)")
                                haveKeys = true
                                self.updateView()
                            }
                        }
                    }) { Text("Get diagnosis key") }.disabled(self.haveKeys)

                    Button(action: {
                        withAnimation {
                            self.framework.eraseExposureLogs()
                        }
                        }) { Text("Delete exposure log") }.disabled(self.framework.exposureLogsErased)

                    if multipeerService.mode == .host {
                        Button(action: { withAnimation {
                            self.experimentRunning = true
                            self.localStore.experimentStart = Date().addingTimeInterval(20)
                            self.localStore.experimentEnd = self.localStore.experimentStart!.addingTimeInterval(60.0 * Double(self.duration))
                        } }) {
                            Text("Start experiment")
                        }
                    } else {
                        Text("wait for experiment to be started")
                    }
                }
                Section(header: Text("Participants").font(.title)) {
                    ForEach(Array(multipeerService.peers.values), id: \.id) {
                        Text($0.label)
                            .foregroundColor($0.color(self.multipeerService))
                    }
                }
            }

        }.padding()
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("There is no host"), message: Text("Do you wish to become host?"), primaryButton: .default(Text("Yes")) {
                    print("Becoming host")
                    self.multipeerService.mode = .host
                    self.actionHeader = "Hosting; Actions needed"
                }, secondaryButton: .cancel { self.declinedHost = true })
            }.onAppear {
                updateView()

                let center = NotificationCenter.default
                let mainQueue = OperationQueue.main
                becomeActiveObserver = center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: mainQueue) { _ in
                    print("become active")
                    updateView()
                }
            }.onDisappear {
                if let o = becomeActiveObserver {
                    NotificationCenter.default.removeObserver(o)
                }
            }
            .navigationBarTitle("Multipeer experiment", displayMode: .inline)
    }
}

struct ExperimentSetupView_Previews: PreviewProvider {
    static let localStore = LocalStore(userName: "Alice", testData: [EncountersWithUser.testData])

    static var previews: some View {
        NavigationView { MultipeerExperimentView() }
            .environmentObject(localStore)
            .environmentObject(MultipeerService(ExposureFramework.shared))
            .previewDevice(PreviewDevice(rawValue: "iPhone SE (2nd generation"))
    }
}
