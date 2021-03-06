//
//  MyLibrary.swift
//  Relisten
//
//  Created by Alec Gorge on 5/23/18.
//  Copyright © 2018 Alec Gorge. All rights reserved.
//

import Foundation

import SwiftyJSON
import Cache
import SINQ
import Observable

import RealmSwift

public class MyLibraryFavorites {
    public var artists: Results<FavoritedArtist> {
        get {
            let realm = try! Realm()
            return realm.objects(FavoritedArtist.self)
        }
    }
    
    public var shows: Results<FavoritedShow> {
        get {
            let realm = try! Realm()
            return realm.objects(FavoritedShow.self)
        }
    }
    
    public var sources: Results<FavoritedSource> {
        get {
            let realm = try! Realm()
            return realm.objects(FavoritedSource.self)
        }
    }
    
    public func sources(byArtist artist: SlimArtist) -> Results<FavoritedSource> {
        return sources
            .filter("artist_uuid == %@", artist.uuid.uuidString)
    }
    
    public var tracks: Results<FavoritedTrack> {
        get {
            let realm = try! Realm()
            return realm.objects(FavoritedTrack.self)
        }
    }
}

public typealias FullOfflineSource = (show: ShowWithSources, source: SourceFull, date_added: Date)

public class MyLibraryOffline {
    public var sources: Results<OfflineSource> {
        get {
            let realm = try! Realm()
            return realm.objects(OfflineSource.self)
        }
    }
    
    public func sources(byArtist artist: SlimArtist) -> Results<OfflineSource> {
        return sources
            .filter("artist_uuid == %@", artist.uuid.uuidString)
    }
    
    public var tracks: Results<OfflineTrack> {
        get {
            let realm = try! Realm()
            return realm.objects(OfflineTrack.self)
        }
    }
}

public class MyLibraryRecentlyPlayed {
    public var shows: Results<RecentlyPlayedTrack> {
        get {
            let realm = try! Realm()
            return realm
                .objects(RecentlyPlayedTrack.self)
                .sorted(by: [SortDescriptor(keyPath: "show_uuid", ascending: true), SortDescriptor(keyPath: "updated_at", ascending: false)])
                .sorted(byKeyPath: "updated_at", ascending: false)
                .distinct(by: ["show_uuid"])
            
        }
    }
    
    public func shows(byArtist artist: SlimArtist) -> Results<RecentlyPlayedTrack> {
        return shows
            .filter("artist_uuid == %@", artist.uuid.uuidString)
    }
    
    public var tracks: Results<RecentlyPlayedTrack> {
        get {
            let realm = try! Realm()
            return realm
                .objects(RecentlyPlayedTrack.self)
                .sorted(byKeyPath: "updated_at", ascending: false)
        }
    }
}

public class MyLibrary {
    public static let shared = MyLibrary()

    public let recent = MyLibraryRecentlyPlayed()
    public let offline = MyLibraryOffline()
    public let favorites = MyLibraryFavorites()
    
    public var downloadBacklog: [Track] = []
    
    internal let realmQueue : ReentrantDispatchQueue = ReentrantDispatchQueue(label: "live.relisten.library.realm")
    internal let diskUseQueue : ReentrantDispatchQueue = ReentrantDispatchQueue(label: "live.relisten.library.diskUse")
    
    private init() {
    }
}

// MARK: Recently Played
extension MyLibrary {
    public func trackWasPlayed(_ track: Track) -> Bool {
        let realm = try! Realm()
        
        let recentShow = RecentlyPlayedTrack()
        recentShow.show_uuid = track.showInfo.show.uuid.uuidString
        recentShow.source_uuid = track.showInfo.source.uuid.uuidString
        recentShow.artist_uuid = track.showInfo.artist.uuid.uuidString
        recentShow.track_uuid = track.sourceTrack.uuid.uuidString
        
        recentShow.created_at = Date()
        recentShow.updated_at = Date()
        
        try! realm.write {
            realm.add(recentShow)
        }
        
        return true
    }
    
    public func importRecentlyPlayedShow(_ showInfo: CompleteShowInformation) -> Bool {
        let realm = try! Realm()
        
        let existingFavoritedShow = realm.objects(RecentlyPlayedTrack.self).filter("show_uuid == %@ AND source_uuid == %@", showInfo.show.uuid.uuidString, showInfo.source.uuid.uuidString).first
        
        if existingFavoritedShow == nil,
           let trackUUID = showInfo.source.tracksFlattened.first?.uuid.uuidString
        {
            let recentShow = RecentlyPlayedTrack()
            recentShow.show_uuid = showInfo.show.uuid.uuidString
            recentShow.source_uuid = showInfo.source.uuid.uuidString
            recentShow.artist_uuid = showInfo.artist.uuid.uuidString
            recentShow.track_uuid = trackUUID
            
            recentShow.created_at = Date()
            recentShow.updated_at = Date()
            
            do {
                try realm.write {
                    realm.add(recentShow)
                }
            } catch {
                LogError("Error importing recently played show to Realm \(showInfo): \(error)")
            }
        }
        
        return true
    }
}

// MARK: Offline Tracks
extension MyLibrary {
    public func offlinePlayedByArtist(_ artist: SlimArtist) -> Results<OfflineSource> {
        return offline.sources
            .filter("artist_uuid == %@", artist.uuid.uuidString)
            .sorted(byKeyPath: "created_at", ascending: false)
    }
    
    public func isTrackAvailableOffline(_ track: Track) -> Bool {
        return isTrackAvailableOffline(track.sourceTrack)
    }
    
    public func isTrackAvailableOffline(_ track: SourceTrack) -> Bool {
        return offline.tracks.filter("track_uuid == %@ AND state >= %d", track.uuid.uuidString, OfflineTrackState.downloaded.rawValue).count > 0
    }
    
    public func isSourceFullyAvailableOffline(_ source: SourceFull) -> Bool {
        if sinq(source.tracksFlattened).any({ !isTrackAvailableOffline($0) }) {
            return false
        }
        
        return true
    }
    
    public func isArtistAtLeastPartiallyAvailableOffline(_ artist: SlimArtist) -> Bool {
        return offline.tracks.filter("artist_uuid == %@ AND state >= %d", artist.uuid.uuidString, OfflineTrackState.downloaded.rawValue).count > 0
    }
    
    public func isShowAtLeastPartiallyAvailableOffline(_ show: Show) -> Bool {
        return offline.tracks.filter("show_uuid == %@ AND state >= %d", show.uuid.uuidString, OfflineTrackState.downloaded.rawValue).count > 0
    }
    
    public func isSourceAtLeastPartiallyAvailableOffline(_ source: SourceFull) -> Bool {
        return offline.tracks.filter("source_uuid == %@ AND state >= %d", source.uuid.uuidString, OfflineTrackState.downloaded.rawValue).count > 0
    }
    
    public func isYearAtLeastPartiallyAvailableOffline(_ year: Year) -> Bool {
        return offline.sources.filter("year_uuid == %@", year.uuid.uuidString).count > 0
    }
}


extension MyLibrary : DownloadManagerDataSource {
    public func nextTrackToDownload() -> Track? {
        let realm = try! Realm()
        
        return realm.objects(OfflineTrack.self)
            .filter("state == %d", OfflineTrackState.downloadQueued.rawValue)
            .sorted(byKeyPath: "created_at", ascending: true)
            .first?
            .track
    }
    
    public func tracksToDownload(_ count : Int) -> [Track]? {
        let realm = try! Realm()
        
        let objects = realm.objects(OfflineTrack.self)
            .filter("state == %d", OfflineTrackState.downloadQueued.rawValue)
            .sorted(byKeyPath: "created_at", ascending: true)
        
        return objects[0..<min(objects.count, count)].compactMap({ $0.track })
    }
    
    public func currentlyDownloadingTracks() -> [Track]? {
        let realm = try! Realm()
        
        let objects = realm.objects(OfflineTrack.self)
            .filter("state == %d", OfflineTrackState.downloading.rawValue)
            .sorted(byKeyPath: "created_at", ascending: true)
        
        return objects.compactMap({ $0.track })
    }
    
    public func importDownloadedTrack(_ track : Track, withSize fileSize: UInt64) {
        let realm = try! Realm()
        
        let trackMeta = OfflineTrack()
        trackMeta.track_uuid = track.sourceTrack.uuid.uuidString
        trackMeta.show_uuid = track.showInfo.show.uuid.uuidString
        trackMeta.source_uuid = track.showInfo.source.uuid.uuidString
        trackMeta.artist_uuid = track.showInfo.artist.uuid.uuidString
        trackMeta.state = .downloaded
        trackMeta.file_size.value = Int(fileSize)
        trackMeta.created_at = Date()
        
        do {
            try realm.write {
                realm.add(trackMeta)
            }
        } catch {
            LogError("Error adding downloaded track \(track) to Realm: \(error)")
        }
        
        addOfflineSourceInfoForDownloadedTrack(track)
    }

    public func offlineTrackQueuedToBacklog(_ track: Track) {
        let realm = try! Realm()
        
        let offlineTrackQuery = realm.object(ofType: OfflineTrack.self, forPrimaryKey: track.uuid.uuidString)
        if let offlineTrack = offlineTrackQuery {
            try! realm.write {
                offlineTrack.state = .downloadQueued
            }
        } else {
            let trackMeta = OfflineTrack()
            trackMeta.track_uuid = track.sourceTrack.uuid.uuidString
            trackMeta.show_uuid = track.showInfo.show.uuid.uuidString
            trackMeta.source_uuid = track.showInfo.source.uuid.uuidString
            trackMeta.artist_uuid = track.showInfo.artist.uuid.uuidString
            trackMeta.state = .downloadQueued
            trackMeta.created_at = Date()
        
            try! realm.write {
                realm.add(trackMeta)
            }
        }
    }
    
    public func offlineTrackBeganDownloading(_ track: Track) {
        let realm = try! Realm()
        
        let offlineTrackQuery = realm.object(ofType: OfflineTrack.self, forPrimaryKey: track.uuid.uuidString)
        
        if let offlineTrack = offlineTrackQuery {
            try! realm.write {
                offlineTrack.state = .downloading
            }
        }
    }
    
    public func offlineTrackFailedDownloading(_ track: Track, error: Error?) {
        let realm = try! Realm()
        
        let offlineTrackQuery = realm.object(ofType: OfflineTrack.self, forPrimaryKey: track.uuid.uuidString)
        
        if let offlineTrack = offlineTrackQuery {
            try! realm.write {
                realm.delete(offlineTrack)
            }
        }
    }

    private func addOfflineSourceInfoForDownloadedTrack(_ track: Track) {
        let realm = try! Realm()
        let offlineSourceQuery = realm.object(ofType: OfflineSource.self, forPrimaryKey: track.showInfo.source.uuid.uuidString)
        
        if offlineSourceQuery == nil {
            do {
                try realm.write {
                    let sourceMeta = OfflineSource()
                    sourceMeta.show_uuid = track.showInfo.show.uuid.uuidString
                    sourceMeta.source_uuid = track.showInfo.source.uuid.uuidString
                    sourceMeta.artist_uuid = track.showInfo.artist.uuid.uuidString
                    sourceMeta.year_uuid = track.showInfo.show.year.uuid.uuidString
                    sourceMeta.created_at = Date()
                    
                    realm.add(sourceMeta)
                }
            } catch {
                LogError("Error adding offline source for track in Realm \(track): \(error)")
            }
        }
    }
    
    public func offlineTrackFinishedDownloading(_ track: Track, withSize fileSize: UInt64) {
        let realm = try! Realm()
        
        let offlineTrackQuery = realm.object(ofType: OfflineTrack.self, forPrimaryKey: track.uuid.uuidString)
        
        if let offlineTrack = offlineTrackQuery {
            try! realm.write {
                offlineTrack.state = .downloaded
                offlineTrack.file_size.value = Int(fileSize)
            }
            
            // add the source information if it doesn't exist
            addOfflineSourceInfoForDownloadedTrack(track)
        }
    }
    
    public func offlineTrackWillBeDeleted(_ track: Track) {
        let realm = try! Realm()
        let offlineTrackQuery = realm.object(ofType: OfflineTrack.self, forPrimaryKey: track.uuid.uuidString)
        
        if let offlineTrack = offlineTrackQuery {
            try! realm.write {
                offlineTrack.state = .deleting
            }
        }
        // If we didn't find a track in Realm it's ok. Someone probably just tried to delete a whole show and only some of the tracks in that show were downloaded
    }
    
    public func offlineTrackWasDeleted(_ track: Track) {
        let realm = try! Realm()
        let offlineTrackQuery = realm.object(ofType: OfflineTrack.self, forPrimaryKey: track.sourceTrack.uuid.uuidString)
        
        guard let offlineTrack = offlineTrackQuery else {
            return
        }
        
        try! realm.write {
            realm.delete(offlineTrack)
        }
        
        if !isSourceAtLeastPartiallyAvailableOffline(track.showInfo.source) {
            let offlineSourceQuery = realm.object(ofType: OfflineSource.self, forPrimaryKey: track.showInfo.source.uuid.uuidString)
            
            if let offlineSource = offlineSourceQuery {
                try! realm.write {
                    realm.delete(offlineSource)
                }
            }
        }
    }
    
    public func deleteAllTracks(_ completion : @escaping () -> Void) {
        let realm = try! Realm()
        
        let offlineTracks = realm.objects(OfflineTrack.self)
        let offlineSources = realm.objects(OfflineSource.self)
        
        try! realm.write {
            realm.delete(offlineTracks)
            realm.delete(offlineSources)
        }
        completion()
    }
}

// MARK: Favorites
extension MyLibrary {
    public func favoritedSourcesPlayedByArtist(_ artist: SlimArtist) -> Results<FavoritedSource> {
        return favorites.sources
            .filter("artist_uuid == %@", artist.uuid.uuidString)
            .sorted(byKeyPath: "show_date", ascending: false)
    }
    
    public func favoriteSource(show: CompleteShowInformation) {
        let realm = try! Realm()
        
        let favoritedSourceQuery = realm.object(ofType: FavoritedSource.self, forPrimaryKey: show.source.uuid.uuidString)
        let existingFavoriteSource = favoritedSourceQuery
        if existingFavoriteSource == nil {
            let favoritedSource = FavoritedSource()
            favoritedSource.artist_uuid = show.artist.uuid.uuidString
            favoritedSource.show_date = show.show.date
            favoritedSource.uuid = show.source.uuid.uuidString
            favoritedSource.show_uuid = show.show.uuid.uuidString
            
            favoritedSource.created_at = Date()
            
            try! realm.write {
                realm.add(favoritedSource)
            }
        }
    }
    
    public func unfavoriteSource(show: CompleteShowInformation) -> Bool {
        let realm = try! Realm()
        
        let favoritedSourceQuery = realm.object(ofType: FavoritedSource.self, forPrimaryKey: show.source.uuid.uuidString)

        if let favoritedSource = favoritedSourceQuery {
            try! realm.write {
                realm.delete(favoritedSource)
            }
            
            return true
        }
        
        return false
    }
    
    public func favoriteArtist(artist: ArtistWithCounts) {
        let realm = try! Realm()
        
        let favoritedArtist = FavoritedArtist()
        favoritedArtist.uuid = artist.uuid.uuidString
        favoritedArtist.created_at = Date()
        
        try! realm.write {
            realm.add(favoritedArtist)
        }
    }
    
    public func removeArtist(artist: ArtistWithCounts) -> Bool {
        let realm = try! Realm()
        
        let favoritedArtistQuery = realm.object(ofType: FavoritedArtist.self, forPrimaryKey: artist.uuid.uuidString)
        
        if let favoritedArtist = favoritedArtistQuery {
            try! realm.write {
                realm.delete(favoritedArtist)
            }
            
            return true
        }
        
        return false
    }
}

// MARK: Favorite queries
public extension MyLibrary {
    public func isFavorite(artist: SlimArtist) -> Bool {
        return favorites.artists.filter("uuid == %@", artist.uuid.uuidString).count > 0
    }
    
    public func isFavorite(show: ShowWithSources, byArtist: SlimArtist) -> Bool {
        return favorites.shows.filter("uuid == %@", show.uuid.uuidString).count > 0
    }
    
    public func isFavorite(source: SourceFull) -> Bool {
        return favorites.sources.filter("uuid == %@", source.uuid.uuidString).count > 0
    }

    public func isFavorite(track: SourceTrack) -> Bool {
        return favorites.tracks.filter("uuid == %@", track.uuid.uuidString).count > 0
    }
}
