//
//  Group.swift
//  Orion
//
//  Created by Ali Hamza Azam on 30/11/2024.
//

import Foundation

struct Group: Identifiable {
    let id: UUID
    let name: String
    var members: [UUID]
}

