//
//  DiaryView.swift
//  GAEN_Explorer
//
//  Created by Bill on 6/7/20.
//  Copyright © 2020 Ninja Monkey Coders. All rights reserved.
//

import SwiftUI

struct DiaryView: View {
    @EnvironmentObject var localStore: LocalStore
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Text(self.localStore.experimentMessage ?? "No experiment running").padding()
                List {
                    ForEach(self.localStore.diary, id: \.at) { d in
                        HStack {
                            Text(d.time).frame(width: geometry.size.width / 4)
                            Text(d.kind.description)
                            Text(d.text)
                        }
                    }
                }
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { self.localStore.addDiaryEntry(DiaryKind.memo, "Test") }) {
                        Text("Memo")
                    }
                    Spacer()
                }
            }
        }.navigationBarTitle("Diary for \(self.localStore.userName)", displayMode: .inline)
    }
}

struct DiaryView_Previews: PreviewProvider {
    static let localStore = LocalStore(userName: "Alice", testData: [EncountersWithUser.testData], diary: DiaryEntry.testData)

    static var previews: some View {
        NavigationView {
            DiaryView().environmentObject(localStore)
        }
    }
}
