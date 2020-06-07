//
//  StartExperimentView.swift
//  GAEN_Explorer
//
//  Created by Bill on 6/7/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import SwiftUI

struct StartExperimentView: View {
    @EnvironmentObject var localStore: LocalStore
    @EnvironmentObject var framework: ExposureFramework
    @State var step: Int

    var body: some View {
        VStack {
            Button(action: {
                self.framework.isEnabled = false
                self.step = 2

            }) { Text("Turn off exposure logging").font(.title) }.padding(.vertical).disabled(step != 1)
            Text("This will turn off exposure logging so we can get a clean start")

            Button(action: {
                self.step = 3
                UIApplication.shared.open(URL(string: "App-prefs:root=Privacy")!)
        }) { Text("Delete exposure Log").font(.title) }.padding(.vertical).disabled(step != 2)
            Text("You have to go to Settings->Privacy->Health->COVID-19 Exposure Logging, scroll all the way down to the bottom, and then select the \"Delete Exposure Log\" button twice.")

            Button(action: {
                self.localStore.startExperiment(self.framework)
                self.localStore.viewShown = nil
                self.step = 1
                   }) { Text("Start Experiment").font(.title) }.padding(.vertical).disabled(step != 3)
            Text("This will resume exposure logging and start the experiment")

        }.padding().navigationBarTitle("Starting experiment", displayMode: .inline)
    }
}

struct StartExperimentView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            StartExperimentView(step: 1).environmentObject(LocalStore.shared)
        }
    }
}
