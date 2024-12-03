//
//  OrionServerApp.swift
//  Orion
//
//  Created by Ali Hamza Azam on 28/11/2024.
//

import Foundation

//@main
struct OrionServerApp {
    static func main() {
        
        let port: UInt16 = 8080
        let server = Server()
        
        print("Starting server...")
        DispatchQueue.global().async {
            server.start(port: port)
        }

        // Keep the main thread alive
        RunLoop.main.run()
    }
}
