//
//  Group.swift
//  Orion
//
//  Created by Ali Hamza Azam on 03/12/2024.
//

import Foundation

struct Group : Identifiable {
    let id: UUID
    let name: String
    let members: [UUID]
}

