//
//  ConfigurationView.swift
//  GAEN_Explorer
//
//  Created by Bill on 5/24/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import SwiftUI

struct ConfigurationView: View {
    @State var config: CodableExposureConfiguration
    var body: some View {
        Form {
            Section(header: Text("Attenuation").font(.title)) {
                HStack {
                    Text("attenuationLevels")
                    Spacer()
                    Text("[\(config.attenuationLevelValues.map { String($0) }.joined(separator: ", "))]")
                }
                HStack { Text("attenuationDurationThresholds")
                    Spacer()
                    Text("\(config.attenuationDurationThresholds[0]) /  \(config.attenuationDurationThresholds[1])")
                }
            }
            Section(header: Text("Other").font(.title)) {
                HStack {
                    Text("transmissionRiskLevels")
                    Spacer()
                    Text("[\(config.transmissionRiskLevelValues.map { String($0) }.joined(separator: ", "))]")
                }
                HStack {
                    Text("durationLevels")
                    Spacer()
                    Text("[\(config.durationLevelValues.map { String($0) }.joined(separator: ", "))]")
                }
                HStack {
                    Text("daysSinceExposure")
                    Spacer()
                    Text("[\(config.daysSinceLastExposureLevelValues.map { String($0) }.joined(separator: ", "))]")
                }
            }

        }.navigationBarTitle("Exposure Configuration", displayMode: .inline)
    }
}

struct ConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ConfigurationView(config: CodableExposureConfiguration.shared)
        }
    }
}
