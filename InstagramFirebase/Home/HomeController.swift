//
//  HomeController.swift
//  InstagramFirebase
//
//  Created by Jushy Shen on 2018/9/9.
//  Copyright © 2018年 Jushy Shen. All rights reserved.
//

import UIKit
import Firebase

class HomeController: UICollectionViewController, UICollectionViewDelegateFlowLayout, HomePostCellDelegate {
    
    let cellId = "cellId"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleUpdateFeed), name: SharePhotoController.updateFeedNotificationName, object: nil)
        
        collectionView?.backgroundColor = .white
        
        collectionView?.register(HomePostCell.self, forCellWithReuseIdentifier: cellId)
        
        let refreshControll = UIRefreshControl()
        refreshControll.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        collectionView?.refreshControl = refreshControll
        
        setupNavigationItems()
        
        fetchAllPosts()
        
    }
    
    @objc func handleUpdateFeed() {
        handleRefresh()
    }
    
    
    @objc func handleRefresh() {
        print("Handleing refresh..")
        posts.removeAll()
        fetchAllPosts()
    }
    
    fileprivate func fetchAllPosts() {
        fetchPosts()
        fetchFollowingUserIds()
    }
    
    fileprivate func fetchFollowingUserIds() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        Database.database().reference().child("following").child(uid).observeSingleEvent(of: .value, with: { (snapshot) in
            
            guard let userIdsDictionary = snapshot.value as? [String: Any] else { return }
            
            userIdsDictionary.forEach({ (key, value) in
                Database.fetchUserWithUID(uid: key, completion: { (user) in
                    self.fetchPostsWithUser(user: user)
                })
            })
            
            
        }) { (err) in
            print("Failed to fetch following user ids:", err)
        }
        
    }
    
    //iOS9
    //let refrshControll = UIRefreshControll
    
    
    var posts = [Post]()
    fileprivate func fetchPosts() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        Database.fetchUserWithUID(uid: uid) { (user) in
            self.fetchPostsWithUser(user: user)
        }
        
    }
    
    fileprivate func fetchPostsWithUser(user: User) {
        
//       guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let ref = Database.database().reference().child("posts").child(user.uid)
        ref.observeSingleEvent(of: .value, with: { (snapshot) in
            //print(snapshot.value)
            
            self.collectionView?.refreshControl?.endRefreshing()
            
            guard let dictionaries = snapshot.value as? [String: Any] else { return }
            
            dictionaries.forEach({ (key, value) in
                print("Key \(key), value \(value)")
                guard let dictionary = value as? [String: Any] else { return }
                
                var post = Post(user: user, dictionary: dictionary)
                post.id = key
                
                guard let uid = Auth.auth().currentUser?.uid else { return }
                Database.database().reference().child("likes").child(key).child(uid).observeSingleEvent(of: .value, with: { (snapshot) in
                    print(snapshot)
                    
                    if let value = snapshot.value as? Int, value == 1 {
                        post.hasLiked = true
                    } else {
                        post.hasLiked = false
                    }
                    
                    self.posts.append(post)
                    self.posts.sort(by: { (p1, p2) -> Bool in
                        return p1.creationDate.compare(p2.creationDate) == .orderedDescending
                    })
                    
                    self.collectionView?.reloadData()
                }, withCancel: { (err) in
                    print("Failed to fetch like info for post:", err)
                })
           
            })
            
        }) { (err) in
            print("Failed to fetch posts:", err)
        }
    }
    
    func setupNavigationItems() {
        navigationItem.titleView = UIImageView(image: #imageLiteral(resourceName: "logo2"))
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(image: #imageLiteral(resourceName: "camera3").withRenderingMode(.alwaysOriginal) , style: .plain, target: self, action: #selector(handleCamera))
    }
    
    @objc func handleCamera() {
        print("Showing camera")
        
        let cameraController = CameraController()
        present(cameraController, animated: true, completion: nil)
        
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        
        var height: CGFloat = 40 + 8 + 8 // username userprofileimageview
        height += view.frame.width
        height += 50
        height += 60
        
        return CGSize(width: view.frame.width, height: height)
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return posts.count
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! HomePostCell
//        cell.post = posts[indexPath.item]
//        cell.delegate = self
        if indexPath.item < posts.count {
            cell.post = posts[indexPath.item]
            cell.delegate = self
        }
       
        return cell
    }
    
    func didTapComment(post: Post) {
        print("Message coming from HomeController")
        print(post.caption)
        let commentsController = CommentsController(collectionViewLayout: UICollectionViewFlowLayout())
        commentsController.post = post
        navigationController?.pushViewController(commentsController, animated: true)
    }
    
    func didLike(for cell: HomePostCell) {
        print("Handling like inside of controller")
        
        guard let indexPath = collectionView.indexPath(for: cell) else { return }
        
        var post = self.posts[indexPath.item]
        print(post.caption)
        
        guard let postId = post.id else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        let values = [uid: post.hasLiked == true ? 0 : 1]
        
        Database.database().reference().child("likes").child(postId).updateChildValues(values) { (err, _) in
            if let err = err {
                print("Failed to like post: ", err)
                return
            }
            
            print("Successfully like post.")
            
            post.hasLiked = !post.hasLiked
            
            self.posts[indexPath.item] = post
            
            self.collectionView.reloadItems(at: [indexPath])
            
        }
        
    }

}
