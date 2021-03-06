//
//  PlaybackController.swift
//  Relisten
//
//  Created by Alec Gorge on 7/3/17.
//  Copyright © 2017 Alec Gorge. All rights reserved.
//

import Foundation

import AGAudioPlayer
import Observable
import StoreKit
import Crashlytics

extension AGAudioPlayerViewController : TrackStatusActionHandler {
    public func trackButtonTapped(_ button: UIButton, forTrack track: Track) {
        TrackActions.showActionOptions(fromViewController: self, inView: button, forTrack: track)
    }
}

@objc public class PlaybackController : NSObject {
    public let playbackQueue: AGAudioPlayerUpNextQueue
    public let player: AGAudioPlayer
    public let viewController: AGAudioPlayerViewController
    public let shrinker: PlaybackMinibarShrinker
    
    public let observeCurrentTrack = Observable<Track?>(nil)
    public let trackWasPlayed = Observable<Track?>(nil)
    
    public let eventTrackPlaybackChanged = Event<Track?>()
    public let eventTrackPlaybackStarted = Event<Track?>()
    public let eventTrackWasPlayed = Event<Track>()

    public static var window: UIWindow? = nil
    
    public static let sharedInstance = PlaybackController()
    
    public required override init() {
        playbackQueue = AGAudioPlayerUpNextQueue()
        player = AGAudioPlayer(queue: playbackQueue)
        viewController = AGAudioPlayerViewController(player: player)
        
        shrinker = PlaybackMinibarShrinker(window: PlaybackController.window, barHeight: viewController.barHeight)
        
        super.init()
        
        viewController.presentationDelegate = self
        viewController.cellDataSource = self
        viewController.delegate = self
        
        viewController.loadViewIfNeeded()
        
        /*
        RelistenDownloadManager.shared.eventTrackStartedDownloading.addHandler(target: self, handler: PlaybackController.relayoutIfContainsTrack)
        RelistenDownloadManager.shared.eventTracksQueuedToDownload.addHandler(target: self, handler: PlaybackController.relayoutIfContainsTracks)
        RelistenDownloadManager.shared.eventTrackFinishedDownloading.addHandler(target: self, handler: PlaybackController.relayoutIfContainsTrack)
        RelistenDownloadManager.shared.eventTracksDeleted.addHandler(target: self, handler: PlaybackController.relayoutIfContainsTracks)
         */
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError()
    }
    
    func relayoutIfContainsTrack(_ track: Track) {
        if let _ = playbackQueue.findSourceTrackAudioItem(forTrack: track) {
            viewController.tableReloadData()
        }
    }
    
    func relayoutIfContainsTracks(_ tracks: [Track]) {
        for track in tracks {
            if let _ = playbackQueue.findSourceTrackAudioItem(forTrack: track) {
                viewController.tableReloadData()
            }
        }
    }
    
    public func displayMini(on vc: UIViewController, completion: (() -> Void)?) {
        if let nav = vc.navigationController {
            nav.delegate = shrinker
        }
        
        addBarIfNeeded()
        
        shrinker.fix(viewController: vc)
    }
    
    public func hideMini(_ completion: (() -> Void)? = nil) {
        if hasBarBeenAdded {
            UIView.animate(withDuration: 0.3, animations: {
                if let w = PlaybackController.window {
                    self.viewController.view.frame = CGRect(
                        x: 0,
                        y: w.bounds.height,
                        width: self.viewController.view.bounds.width,
                        height: self.viewController.view.bounds.height
                    )
                }
            }, completion: { _ in
                if let c = completion {
                    c()
                }
            })
        }
    }
    
    public func display(_ completion: ((Bool) -> Void)? = nil) {
        viewController.viewWillAppear(true)
        viewController.switchToFullPlayer(animated: true)

        UIView.animate(withDuration: 0.3, animations: {
            self.viewController.view.frame = CGRect(
                x: 0,
                y: 0,
                width: self.viewController.view.bounds.width,
                height: self.viewController.view.bounds.height
            )
        }, completion: { (b) -> Void in self.viewController.viewDidAppear(true) })
    }
    
    public func dismiss(_ completion: ((Bool) -> Void)? = nil) {
        viewController.switchToMiniPlayer(animated: true)
        UIView.animate(withDuration: 0.3, animations: {
            if let w = PlaybackController.window {
                self.viewController.view.frame = CGRect(
                    x: 0,
                    y: w.bounds.height - self.viewController.barHeight,
                    width: self.viewController.view.bounds.width,
                    height: self.viewController.view.bounds.height
                )
            }
        }, completion: completion)
    }
    
    public private(set) var hasBarBeenAdded = false
    public func addBarIfNeeded() {
        if !hasBarBeenAdded, let w = PlaybackController.window {
            viewController.viewWillAppear(true)
            
            w.addSubview(viewController.view)
            
            viewController.viewDidAppear(true)
            
            let barHeight = viewController.barHeight
            let windowHeight = w.bounds.height
            
            viewController.view.frame = CGRect(
                x: 0,
                y: windowHeight,
                width: w.bounds.width,
                height: windowHeight
            )
            
            UIView.animate(withDuration: 0.3, animations: { 
                self.viewController.view.frame = CGRect(
                    x: 0,
                    y: windowHeight - barHeight,
                    width: w.bounds.width,
                    height: windowHeight
                )
            })
            
            hasBarBeenAdded = true
        }
    }

    private var cellContentViewWidth: CGFloat = CGFloat(0)
}

extension PlaybackController : AGAudioPlayerViewControllerPresentationDelegate {
    public func fullPlayerRequested() {
        display()
    }

    public func fullPlayerDismissRequested(fromProgress: CGFloat) {
        self.viewController.viewWillDisappear(true)
        
        UIView.animate(withDuration: 0.3, animations: {
            self.fullPlayerDismissProgress(1.0)
        }) { (b) in
            self.viewController.viewDidDisappear(true)
        }
    }
    
    func fullPlayerDismissProgress(_ progress: CGFloat) {
        if let w = PlaybackController.window {
            
            var vFrame = viewController.view.frame
            
            vFrame.origin.y = (w.bounds.height - viewController.barHeight) * progress
            
            viewController.view.frame = vFrame
            
            viewController.switchToMiniPlayerProgress(progress)
        }
    }
    
    public func fullPlayerDismissUpdatedProgress(_ progress: CGFloat) {
        fullPlayerDismissProgress(progress)
    }
    
    public func fullPlayerDismissCancelled(fromProgress: CGFloat) {
        UIView.animate(withDuration: 0.3) {
            self.fullPlayerDismissProgress(0.0)
        }
    }
    
    public func fullPlayerStartedDismissing() {
        
    }
    
    public func fullPlayerOpenUpdatedProgress(_ progress: CGFloat) {
        fullPlayerDismissProgress(1.0 - progress)
    }
    
    public func fullPlayerOpenCancelled(fromProgress: CGFloat) {
        fullPlayerDismissRequested(fromProgress: fromProgress)
    }
    
    public func fullPlayerOpenRequested(fromProgress: CGFloat) {
        self.viewController.viewWillAppear(true)
        UIView.animate(withDuration: 0.3, animations: {
            self.fullPlayerDismissProgress(0.0)
        }) { (b) in
            self.viewController.viewDidAppear(true)
        }
    }
    
    public func setupTableView(_ tableView: UITableView) {
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }
    
    public func tableViewCell(forAudioItem: AGAudioItem, atIndex: IndexPath, inTableView: UITableView) -> UITableViewCell {
        let cell = inTableView.dequeueReusableCell(withIdentifier: "cell", for: atIndex)
        
        if let t = forAudioItem as? SourceTrackAudioItem {
            let v = TrackStatusLayout(withTrack: t.track, withHandler: self)
            v.arrangement(width: inTableView.bounds.size.width) .makeViews(in: cell.contentView)
        }
        
        return UITableViewCell()
    }
}

extension PlaybackController : TrackStatusActionHandler {
    public func trackButtonTapped(_ button: UIButton, forTrack track: Track) {
        TrackActions.showActionOptions(fromViewController: viewController, inView: button, forTrack: track)
    }
}

public class PlaybackMinibarShrinker: NSObject, UINavigationControllerDelegate {
    private let window: UIWindow?
    private let barHeight: CGFloat
    
    public init(window: UIWindow?, barHeight: CGFloat) {
        self.window = window
        self.barHeight = barHeight
    }
    
    public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        fix(viewController: viewController)
    }
    
    public func fix(viewController: UIViewController) {
        if let nav = viewController as? UINavigationController {
            for vc in nav.viewControllers {
                fix(viewController: vc)
            }
        }
        else if let scroll = viewController.view as? UIScrollView {
            fix(scrollView: scroll)
        }
        else {
            for v in viewController.view.subviews {
                if let scroll = v as? UIScrollView {
                    fix(scrollView: scroll)
                }
            }
        }
    }
    
    public func fix(scrollView: UIScrollView) {
        var edges = scrollView.contentInset
        
        if edges.bottom < barHeight {
            edges.bottom += barHeight
        }
        
        scrollView.contentInset = edges
        
        edges = scrollView.scrollIndicatorInsets
        
        if edges.bottom < barHeight {
            edges.bottom += barHeight
        }
        
        scrollView.scrollIndicatorInsets = edges
    }
}

extension PlaybackController : AGAudioPlayerViewControllerDelegate {
    public func audioPlayerViewController(_ agAudio: AGAudioPlayerViewController, trackChangedState audioItem: AGAudioItem?) {
        let completeInfo = (audioItem as? SourceTrackAudioItem)?.track

        eventTrackPlaybackChanged.raise(completeInfo)
        observeCurrentTrack.value = completeInfo
    }
    
    public func audioPlayerViewController(_ agAudio: AGAudioPlayerViewController, changedTrackTo audioItem: AGAudioItem?) {
        let completeInfo = (audioItem as? SourceTrackAudioItem)?.track

        eventTrackPlaybackStarted.raise(completeInfo)
        observeCurrentTrack.value = completeInfo
    }
    
    public func audioPlayerViewController(_ agAudio: AGAudioPlayerViewController, pressedDotsForAudioItem audioItem: AGAudioItem) {
        let completeInfo = (audioItem as! SourceTrackAudioItem).track
        
        TrackActions.showActionOptions(fromViewController: agAudio, inView: agAudio.uiMiniButtonDots, forTrack: completeInfo)
    }
    
    public func audioPlayerViewController(_ agAudio: AGAudioPlayerViewController, pressedPlusForAudioItem audioItem: AGAudioItem) {
        let completeInfo = (audioItem as! SourceTrackAudioItem).track

        let a = UIAlertController(
            title: "Favorite \(completeInfo.showInfo.show.display_date)?",
            message: "Would you like to add \(completeInfo.showInfo.show.display_date) to your favorites?",
            preferredStyle: .actionSheet
        )
        
        a.addAction(UIAlertAction(title: "Favorite ❤️", style: .default, handler: { (action) in
            MyLibrary.shared.favoriteSource(show: completeInfo.showInfo)
        }))
        
        a.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))

        viewController.present(a, animated: true, completion: nil)
    }
    
    public func audioPlayerViewController(_ agAudio: AGAudioPlayerViewController, passedHalfWayFor audioItem: AGAudioItem) {
        let completeInfo = (audioItem as! SourceTrackAudioItem).track
        
        let _ = MyLibrary.shared.trackWasPlayed(completeInfo)
        eventTrackWasPlayed.raise(completeInfo)
        trackWasPlayed.value = completeInfo
        
        if RelistenApp.sharedApp.launchCount > 2 {
            // If the app has been launched at least three full times and the user is halfway through a song they probably like the app.
            // Let's ask for a review.
#if !DEBUG
            // Don't prompt on debug builds since a request pops up every time for testing
            LogDebug("⭐️⭐️⭐️⭐️⭐️ Requesting a review. ⭐️⭐️⭐️⭐️⭐️ ")
            SKStoreReviewController.requestReview()
#endif
        }
    }
}

extension PlaybackController : AGAudioPlayerViewControllerCellDataSource {
    public func cell(inTableView tableView: UITableView, basedOnCell cell: UITableViewCell, atIndexPath: IndexPath, forPlaybackItem playbackItem: AGAudioItem, isCurrentlyPlaying: Bool) -> UITableViewCell {
        let completeInfo = (playbackItem as! SourceTrackAudioItem).track
        
        let layout = TrackStatusLayout(
            withTrack: completeInfo,
            withHandler: viewController,
            usingExplicitTrackNumber: atIndexPath.row + 1,
            showingArtistInformation: true
        )
        
        cellContentViewWidth = cell.contentView.frame.size.width
        
        layout
            .arrangement(width: cellContentViewWidth, height: nil)
            .makeViews(in: cell.contentView, direction: .leftToRight)
        
        return cell
    }
    
    public func heightForCell(inTableView tableView: UITableView, atIndexPath: IndexPath, forPlaybackItem playbackItem: AGAudioItem, isCurrentlyPlaying: Bool) -> CGFloat {
        let completeInfo = (playbackItem as! SourceTrackAudioItem).track
        
        let layout = TrackStatusLayout(
            withTrack: completeInfo,
            withHandler: viewController,
            usingExplicitTrackNumber: atIndexPath.row + 1,
            showingArtistInformation: true
        )
        
        return layout
            .arrangement(width: cellContentViewWidth, height: nil)
            .frame.height
    }
}

extension PlaybackController : AGAudioPlayerLoggingDelegate {
    public func audioPlayer(_ audioPlayer: AGAudioPlayer, loggedLine line: String) {
        LogDebug(line)
    }
    
    public func audioPlayer(_ audioPlayer: AGAudioPlayer, loggedErrorLine line: String) {
        LogError(line)
        
        let err = NSError(domain: "net.relisten.ios", code: 54, userInfo: [
            // current track, queue, bass assertion
            "assertion": line
        ])
        
        Crashlytics.sharedInstance().recordError(err)
    }
}
