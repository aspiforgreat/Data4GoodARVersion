//
//  MapContainer.swift
//  ARCLDemo
//
//  Created by Miron Rogovets on 04.05.2021.
//

import SwiftUI
import CoreLocation
import LocationBasedAR

struct MapContainer: View {
    
    @EnvironmentObject var locationManager: LBSManager
    @EnvironmentObject var arSessionManager: ARSessionManager
    
    var body: some View {
        ZStack {
            PointClusteringExampleRepresentable()
                .ignoresSafeArea(.all, edges: .all)
            VStack {
                HStack {
                    Spacer()
                    
                    
                }
                Spacer()
            }
            .padding(.all, 20)
        }
        .alert(isPresented: $locationManager.permissionDenied, content: {
            .openSettingsAlert(title: "Persmission Denied", message: "Enable Location Tracking in Settings")
        })
        .alert(isPresented: $locationManager.accuracyDenied, content: {
            .openSettingsAlert(title: "Persmission Denied", message: "Enable Full Accuracy Tracking in Settings")
        })
       
    }
}

struct MapContainer_Previews: PreviewProvider {
    static var previews: some View {
        MapContainer()
    }
}
