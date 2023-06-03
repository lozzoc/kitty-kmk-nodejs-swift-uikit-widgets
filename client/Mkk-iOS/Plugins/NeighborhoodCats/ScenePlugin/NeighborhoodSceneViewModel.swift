//
//  NeighborhoodSceneViewModel.swift
//  Mkk-iOS
//
//  Created by Conner Maddalozzo on 4/15/23.
//

import Foundation
import Combine
import SceneKit

enum NeighborhoodScene {}

extension NeighborhoodScene {
    typealias ViewModel = StateManagementViewModel<Observable, NonObservable, Action>
    
    struct Observable {
        var isSceneLoading: Bool = true
        var isZipcodeLoading: Result<NetworkState, KMKNetworkError> = .success(.idle)
        var orientation:  OrientationAwareModifier.Orientation
    }
    
    struct NonObservable {
        var sceneDelegate: SimpleSceneDelegate?
        var neighborhoodModel = NeighborhoodModel()
        var cats: KMKNeighborhood?
        var neighborhoddScene = SCNScene(named: "Neighborhood.scn")
        var tableViewModel: NeighborhoodCatTables.ViewModel?
    }
    
    enum Action {
        
    }
}

extension NeighborhoodScene.ViewModel {
    
    convenience init() {
        self.init(observables: .init(orientation: kmk_initialOrientation()), nonobservables: .init())
        let sceneD = SimpleSceneDelegate() { [weak self] (scene, delay) in
            guard let self = self else { return }
            self.shouldRenderCats(in: scene, offset: delay)
        }
        
        self.nonObservables.sceneDelegate = sceneD
    }
    
}

extension NeighborhoodScene.ViewModel {
    func onSelected(cat: ZipcodeCat) {
        if let animator = self.nonObservables.sceneDelegate?.catAnimator {
            animator.cats.forEach { scenecat in
                if let details = scenecat.catDetails,
                   details == cat {
                    let duration: CFTimeInterval = 2.25
                    let workItem2 = DispatchWorkItem {
                    }
                    CatColorAnimator.shared.animateCat(cat: scenecat, duration: duration, completion: workItem2)
                }
                    
            }
        }
        
    }
    
    private func zipCodeCompletion(_ completion: Subscribers.Completion<KMKNetworkError>) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch completion {
            case .finished:
                return
            case .failure(let error):
                self.observables.isZipcodeLoading = .failure(error)
            }
        }
    }
    private func zipCodeCompletion(_ receiveValue: KMKNeighborhood) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.nonObservables.cats = receiveValue
            self.observables.isZipcodeLoading = .success(.success)
        }
    }
    
    func neighborHoodOnAppear() {
        switch self.isZipcodeLoading {
        case .failure(_):
            flushCancellables()
            fallthrough
        case .success(.idle):
            if let decodedZipCode = KMKNeighborhoodCatCoder().decode() {
                self.nonObservables.cats = decodedZipCode
                self.observables.isZipcodeLoading = .success(.success)
            } else {
                let publisher = self.nonObservables.neighborhoodModel.queryZipCode()
                publisher
                    .sink(receiveCompletion: self.zipCodeCompletion, receiveValue: self.zipCodeCompletion)
                    .store(in: self)
            }
        default:
            return
        }

    }

    private func shouldRenderCats(in scene: SCNScene, offset time: TimeInterval) {
        guard let zipCats = self.nonObservables.cats?.cats else { return }
        let animator: CatAnimator = .init(zipcodeCats: zipCats, start: time)
        self.nonObservables.sceneDelegate?.catAnimator = animator
        animator.load(into: scene)
        
        DispatchQueue.main.async { [weak self] in
            self?.observables.isSceneLoading = false
        }
    }
}


