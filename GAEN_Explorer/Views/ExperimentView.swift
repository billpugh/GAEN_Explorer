//
//  StartExperimentView.swift
//  GAEN_Explorer
//
//  Created by Bill on 6/7/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import SwiftUI

struct ExperimentView: View {
    @EnvironmentObject var localStore: LocalStore
    @EnvironmentObject var framework: ExposureFramework

    @State var computingKeys = false
    @State var showingSheet = false
    @State var showingSheetToShareExposures = false

    var finalButtonTitle: String {
        if !localStore.canAnalyze && localStore.allExposures.count > 0 {
            return "Share your analysis"
        } else if !localStore.canResetAnalysis {
            return "When you have all keys, start analyzing"
        }
        return "Keep analyzing"
    }

    func itemsToShare() -> [Any] {
        if showingSheetToShareExposures {
            return [ExposuresItem(url: localStore.shareExposuresURL!,
                                  title: "Encounters for \(localStore.userName) from GAEN Explorer")]
        }
        return DiagnosisKeyItem(framework.keyCount,
                                localStore.userName,
                                framework.keyURL!).itemsToShare()
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack {
                Group {
                    Button(action: {
                        if self.framework.isEnabled {
                            self.framework.isEnabled = false
                        } else {
                            self.localStore.experimentStep = 3
                            UIApplication.shared.open(URL(string: "App-prefs:root=Privacy")!)
                        }

                    }) { Text(self.framework.isEnabled ? "Turn off exposure scanning" : "Delete exposure Log") }.font(.title).padding(.vertical).disabled(self.localStore.experimentStep != 1)

                    if self.framework.isEnabled {
                        Text("This will turn off scanning and broadcasting of Bluetooth advertisements so we can get a clean start")
                    } else {
                        Text("You have to go to Settings->Privacy->Health->COVID-19 Exposure Logging, scroll all the way down to the bottom, and then select the \"Delete Exposure Log\" button once (twice if it allows you to).").font(.subheadline)
                    }

                    Button(action: {
                        self.localStore.startExperiment(self.framework)
                        self.localStore.viewShown = nil
                        self.localStore.experimentStep = 4
                    }) { Text("Start Experiment").font(.title) }.padding(.vertical).disabled(self.localStore.experimentStep != 3)
                    Text("This will resume exposure scanning and start the experiment. When the experiment is over come back to this screen")

                    Button(action: {
                        self.framework.isEnabled = false

                        self.localStore.experimentStep = 5
                    }) { Text("End the experiment").font(.title) }.padding(.vertical).disabled(self.localStore.experimentStep != 4)
                    Text("When it is time to end the experiment, everyone should stop scanning together")
                } // Group

                Button(action: { self.computingKeys = true
                    self.localStore.getAndPackageKeys { success in
                        print("getAndPackageKeys done")
                        if success {
                            self.showingSheet = true
                            LocalStore.shared.addDiaryEntry(.keysShared)
                            self.localStore.experimentStep = 1
                        }
                        self.computingKeys = false
                    }
                }) { Text("Share keys") }
                    .font(.title).padding(.vertical)
                    .disabled(self.localStore.experimentStep != 5)

                Text(self.localStore.allExposures.count == 0 ? "You currently don't have keys from anyone else"
                    : "You currently have keys from \(self.localStore.allExposures.count) other people")

                Button(action: {
                    if self.localStore.canAnalyze {
                        LocalStore.shared.analyze()
                    } else {
                        self.localStore.exportExposuresToURL()
                        self.showingSheetToShareExposures = true
                        self.showingSheet = true
                        self.localStore.experimentStep = 1
                        print("showingSheet set to true")
                    }
                }
                ) { Text(finalButtonTitle).font(.headline) }
                    .padding(.vertical)
                    .disabled(self.localStore.experimentStep != 5 || self.localStore.allExposures.count == 0)

            }.sheet(isPresented: $showingSheet,
                    onDismiss: { self.showingSheetToShareExposures = false },
                    content: {
                        ActivityView(activityItems: self.itemsToShare(),
                                     applicationActivities: nil, isPresented: self.$showingSheet)
                    })
        }
        .padding().navigationBarTitle("Starting experiment", displayMode: .inline)
    }
}

struct StartExperimentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ExperimentView().environmentObject(LocalStore.shared)
        }
    }
}
