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
    @State var actionHeader: String = "Actions needed"
    @State var declinedHost: Bool = false
    @State var becomeActiveObserver: NSObjectProtocol? = nil
    @State var showingSheetToShareExposures: Bool = false
    @State var showingAlertToLeaveExperiment: Bool = false
    var canBeHost: Bool {
        !declinedHost
            && multipeerService.mode != .host
            && framework.exposureLogsErased
            && framework.keysAreCurrent
            && localStore.observedExperimentStatus == .none
            && multipeerService.peers.isEmpty
    }

    func askHost() {
        guard canBeHost else { return }
        multipeerService.askToBecomeHost = true
    }

    func tryBecomingHost() {
        guard canBeHost else { return }
        multipeerService.mode = .host
    }

    func updateView() {
        withAnimation {
            self.localStore.experimentStatus = .none
            self.multipeerService.mightBeReady()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.askHost()
        }
    }

    func nextMinute(after: Date, andMinutes: Int) -> Date {
        Date(timeIntervalSinceReferenceDate: (after.timeIntervalSinceReferenceDate / 60 + Double(andMinutes)).rounded(.up) * 60)
    }

    func launchExperiment() {
        experimentInitiated = true
        multipeerService.collectKeys()
        let start = Date(timeIntervalSinceNow: 20)
        localStore.experimentStart = start
        localStore.experimentEnd = nextMinute(after: start, andMinutes: localStore.experimentDurationMinutes)
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
                Stepper(value: self.$localStore.experimentDurationMinutes, in: 4 ... 54, step: 5, onEditingChanged: { b in
                    hideKeyboard()
                    print("onEditingChanged \(b) \(self.localStore.experimentDurationMinutes)")
                    if !b {
                        self.multipeerService.sendDesign()
                    }
                }) {
                    Text("Duration \(self.localStore.experimentDurationMinutes) minutes")
                }

                HStack(spacing: 10) {
                    Text(framework.observedIsEnabled ? "Scanning" : "Not scanning")
                    Text("\(multipeerService.mode.rawValue)")
                    Text("\(localStore.experimentStatus.rawValue)")
                }
//                HStack(spacing: 10) {
//                    Text("mode: \(multipeerService.mode.rawValue)")
//                    Text("\(framework.exposureLogsErased ? "erased" : "not erased")")
//                    Text("peers: \(multipeerService.peers.count)")
//                    Button(action: { self.multipeerService.sendDesign() }) { Text("Send design") }
//                }
            }.disabled(multipeerService.mode != .host)
            if self.localStore.observedExperimentStatus != .none {
                Section(header: Text("Experiment: \(String(describing: self.localStore.observedExperimentStatus))").font(.title)) {
                    Text("starts at \(timeFormatter.string(from: localStore.experimentStart!))")
                    Text("ends at \(timeFormatter.string(from: localStore.experimentEnd!))")

                    if self.localStore.observedExperimentStatus == .analyzed {
                        Button(action: {
                            self.localStore.exportExposuresToURL()
                            self.showingSheetToShareExposures = true
                            print("showingSheet set to true")

                        }) {
                            Text("export results")
                        }
                    }
                    if self.localStore.observedExperimentStatus == .analyzed {
                        Button(action: { self.localStore.viewShown = ""
                            self.localStore.observedExperimentStatus = .none
                            self.multipeerService.mode = .off
                        }) {
                            Text("finish experiment")
                        }
                    }
                    if self.localStore.observedExperimentStatus != .analyzed {
                        Button(action: {
                            self.localStore.resetExperiment(self.framework)
                            print("aborting experiment")

                                           }) {
                            Text("Abort experiment")
                        }
                    }
                }.font(.headline).padding().navigationBarTitle("Multipeer experiment running", displayMode: .inline)

            } else {
                Section(header: Text(actionHeader).font(.title)) {
                    Button(action: {
                        withAnimation {
                            self.framework.setExposureNotificationEnabled(false) { _ in
                                DispatchQueue.main.async {
                                    self.framework.eraseExposureLogs()
                                }
                            }
                        }
                        }) { Text("Delete exposure log") }.disabled(self.framework.exposureLogsErased)

                    Button(action: {
                        self.framework.currentKeys(self.localStore.userName) { _ in
                            print("after calling currentKeys, \(self.framework.keysAreCurrent)")
                            self.updateView()
                        }
                                      }) { Text("Get diagnosis key") }.disabled(!self.framework.exposureLogsErased || framework.keysAreCurrent)

                    if multipeerService.mode == .host {
                        Button(action: { withAnimation {
                            hideKeyboard()
                            self.launchExperiment()
                        } }) {
                            Text("Start experiment")
                        }
                    } else {
                        Text("wait for experiment to be started")
                        Button(action: { showingAlertToLeaveExperiment = true })
                        {
                            Text("Decline experiment")
                        }
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
            .alert(isPresented: $multipeerService.askToBecomeHost) {
                Alert(title: Text("There is no host"), message: Text("Do you wish to become host?"), primaryButton: .default(Text("Yes")) {
                    print("Becoming host")
                    self.tryBecomingHost()

                    }, secondaryButton: .cancel { self.declinedHost = true })
            }
            .alert(isPresented: $showingAlertToLeaveExperiment) {
                Alert(title: Text("Abandon experiment"), message: Text("Do you wish to abandon this experiment"), primaryButton: .destructive(Text("Yes")) {
                    self.multipeerService.leaveExperiment()
                    self.localStore.viewShown = nil
                }, secondaryButton: .cancel())
            }.onAppear {
                self.updateView()
                UIApplication.shared.isIdleTimerDisabled = true
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
                UIApplication.shared.isIdleTimerDisabled = false
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
