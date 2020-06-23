//
//  ExperimentSetupView.swift
//  GAEN_Explorer
//
//  Created by Bill on 6/20/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import Grid
import SwiftUI

struct Participant: Identifiable {
    var id: String
    static let testData = ["a", "b", "c", "d", "e", "f", "h", "i"].map { Participant(id: $0) }
}

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
    @State var description: String = ""
    @State var selectedDuration = 2
    @State var experimentRunning: Bool = false
    @State var showingAlert: Bool = false
    @State var actionHeader: String = "Actions needed"
    @State var isHosting: Bool = false
    var timer: Timer?
    @State var started: Bool = false

    @State var remaining: String = "Not started"
    let duration = ["14 min", "19 min", "24 min", "45 min", "60 min"]
    let durationMinutes: [Double] = [14, 19, 24, 45, 60]

    func startExperiment() {}

    var body: some View {
        Form {
            Section(header: Text("Experiment parameters").font(.title)) {
                HStack {
                    Text("Description:").font(.headline)
                    TextField("description", text: self.$description)
                }

                Picker(selection: $selectedDuration, label: Text("Duration:")) {
                    ForEach(0 ..< duration.count) {
                        Text(self.duration[$0])
                    }
                } // .pickerStyle(WheelPickerStyle())
            }
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
                        UIApplication.shared.open(URL(string: "App-prefs:root=Privacy")!)
                     }) { Text("Delete exposure log") }

                    Button(action: {
                        UIApplication.shared.open(URL(string: "App-prefs:root=Privacy")!)
                        }) { Text("Get diagnosis key") }

                    if isHosting {
                        Button(action: { withAnimation {
                            self.experimentRunning = true
                            self.localStore.experimentStart = Date().addingTimeInterval(20)
                            self.localStore.experimentEnd = self.localStore.experimentStart!.addingTimeInterval(60.0 * self.durationMinutes[self.selectedDuration])
                        } }) {
                            Text("Start experiment")
                        }
                    }
                }
                Section(header: Text("Participants").font(.title)) {
                    Grid(Participant.testData) {
                        Text($0.id)
                    }

                    .gridStyle(
                        ModularGridStyle(columns: 2, rows: .fixed(40))
                    )
                }
            }

        }.padding()
            .alert(isPresented: $showingAlert) {
                Alert(title: Text("There is no host"), message: Text("Do you wish to become host?"), primaryButton: .default(Text("Yes")) {
                    print("Becoming host")
                    self.isHosting = true
                    self.actionHeader = "Hosting; Actions needed"
                    }, secondaryButton: .cancel())
            }.onAppear {
                self.showingAlert = true
            }
            .navigationBarTitle("Multipeer experiment", displayMode: .inline)
    }
}

struct ExperimentSetupView_Previews: PreviewProvider {
    static let localStore = LocalStore(userName: "Alice", testData: [EncountersWithUser.testData])

    static var previews: some View {
        NavigationView { MultipeerExperimentView() }
            .environmentObject(localStore)
            .previewDevice(PreviewDevice(rawValue: "iPhone SE (2nd generation"))
    }
}
