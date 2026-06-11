//
//  AppGroup.swift
//  sumi-ios
//
//  Shared container for data BGTasks must read.
//

import Foundation

enum AppGroup {
    static let identifier = "group.Eden-Etuk.sumi-ios"

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier)
    }
}
