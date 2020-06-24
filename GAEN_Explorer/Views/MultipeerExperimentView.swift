//
//  ExperimentSetupView.swift
//  GAEN_Explorer
//
//  Created by Bill on 6/20/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import SwiftUI

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
    @State var experimentInitiated: Bool = false
    @State var showingAlert: Bool = false
    @State var actionHeader: String = "Actions needed"
    @State var declinedHost: Bool = false
    @State var haveKeys: Bool = false
    @State var becomeActiveObserver: NSObjectProtocol? = nil
    @State var showingSheetToShareExposures: Bool = false

    var canBeHost: Bool {
        !declinedHost && multipeerService.mode != .host && framework.exposureLogsErased
            && multipeerService.peers.isEmpty
    }

    func askHost() {
        guard canBeHost else { return }
        showingAlert = true
    }

    func tryBecomingHost() {
        guard canBeHost else { return }
        multipeerService.mode = .host
    }

    func updateView() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.askHost()
        }
        withAnimation {
            haveKeys = framework.keysAreCurrent
            self.multipeerService.mightBeReady()
        }
    }

    var nextStartTime: Date {
        Date(timeIntervalSinceReferenceDate: ((Date().timeIntervalSinceReferenceDate + 10) / 60).rounded(.up) * 60)
    }

    func startExperiment() {
        experimentInitiated = true
        multipeerService.collectKeys()
        localStore.experimentStart = nextStartTime
        localStore.experimentEnd = localStore.experimentStart!.addingTimeInterval(60.0 * Double(localStore.experimentDurationMinutes))
        multipeerService.sendStart()
        localStore.launchExperiment(framework)
    }

    var body: some View {
        Form {
            Section(header: Text("Experiment").font(.title)) {
                HStack {
                    Text("Description:").font(.headline)
                    TextField("description", text: self.$localStore.experimentDescription, onCommit: { self.multipeerService.sendDesign() })
                }
                Stepper(value: self.$localStore.experimentDurationMinutes, in: 1 ... 12, step: 1, onEditingChanged: { b in print("onEditingChanged \(b) \(self.localStore.experimentDurationMinutes)")
                    if !b {
                        self.multipeerService.sendDesign()
                    }
                }) {
                    Text("Duration \(self.localStore.experimentDurationMinutes) minutes")
                }

                Text(framework.isEnabled ? "Scanning" : "Not scanning")
//                HStack(spacing: 10) {
//                    Text("mode: \(multipeerService.mode.rawValue)")
//                    Text("\(framework.exposureLogsErased ? "erased" : "not erased")")
//                    Text("peers: \(multipeerService.peers.count)")
//                    Button(action: { self.multipeerService.sendDesign() }) { Text("Send design") }
//                }
            }.disabled(multipeerService.mode != .host)
            if self.localStore.experimentStatus != .none {
                Section(header: Text("Experiment: \(String(describing: self.localStore.experimentStatus))").font(.title)) {
                    Text("starts at \(timeFormatter.string(from: localStore.experimentStart!))")
                    Text("ends at \(timeFormatter.string(from: localStore.experimentEnd!))")
                    if self.localStore.experimentStatus == .analyzed {
                        Button(action: {
                            self.localStore.exportExposuresToURL()
                            self.showingSheetToShareExposures = true
                            self.localStore.experimentStatus = .none
                            print("showingSheet set to true")

                        }) {
                            Text("export results")
                        }
                    }
                    if self.localStore.experimentStatus != .running {
                        Button(action: { self.localStore.experimentStatus = .none }) {
                            Text("finish experiment")
                        }
                    }
                }.font(.headline).padding().navigationBarTitle("Multipeer experiment running", displayMode: .inline)

            } else {
                Section(header: Text(actionHeader).font(.title)) {
                    Button(action: {
                        self.framework.currentKeys(self.localStore.userName) { _ in
                            print("after calling currentKeys, \(self.framework.keysAreCurrent)")
                            self.haveKeys = true
                            self.updateView()
                        }
                    }) { Text("Get diagnosis key") }.disabled(self.haveKeys)

                    Button(action: {
                        withAnimation {
                            self.framework.setExposureNotificationEnabled(false) { _ in
                                DispatchQueue.main.async {
                                    self.framework.eraseExposureLogs()
                                }
                            }
                        }
                        }) { Text("Delete exposure log") }.disabled(self.framework.exposureLogsErased)

                    if multipeerService.mode == .host {
                        Button(action: { withAnimation {
                            self.startExperiment()
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
            .sheet(isPresented: $showingSheetToShareExposures,
                   content: {
                       ActivityView(activityItems: [ExposuresItem(url: self.localStore.shareExposuresURL!,
                                                                  title: "Encounters for \(self.localStore.userName) from GAEN Explorer")],
                                    applicationActivities: nil, isPresented: self.$showingSheetToShareExposures)
            })
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("There is no host"), message: Text("Do you wish to become host?"), primaryButton: .default(Text("Yes")) {
                    print("Becoming host")
                    self.tryBecomingHost()

                }, secondaryButton: .cancel { self.declinedHost = true })
            }.onAppear {
                self.updateView()

                let center = NotificationCenter.default
                let mainQueue = OperationQueue.main
                self.becomeActiveObserver = center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: mainQueue) { _ in
                    print("become active")
                    self.updateView()
                }
            }.onDisappear {
                if let o = self.becomeActiveObserver {
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
