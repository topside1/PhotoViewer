//
//  MRGAlbumListViewController.m
//  PhotoViewer
//
//  Created by Nikolay Evstigneev on 26.03.16.
//  Copyright © 2016 Nikolay Evstigneev. All rights reserved.
//

#import "MRGAlbumListViewController.h"
#import "MRGAppAssembly.h"
#import "MRGAlbumFetcher.h"
#import "MRGAlbum.h"
#import "MRGAlbumCell.h"
#import "MRGAlbumContentViewController.h"
#import "MRGPresentationHelper.h"
#import "UIViewController+MRGPresentation.h"
#import <Photos/Photos.h>

@interface MRGAlbumListViewController () <UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (strong, nonatomic) NSArray<MRGAlbum *> *albums;

@end

static const CGFloat kRowHeight = 76.0;
static NSString *const kAlbumContentSegue = @"MRGAlbumContentSegue";

@implementation MRGAlbumListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self p_setupViews];
    [self p_checkAuthorization];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.albums.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MRGAlbumCell *cell = [tableView dequeueReusableCellWithIdentifier:[MRGAlbumCell reuseIdentifier] forIndexPath:indexPath];
    MRGAlbum *album = self.albums[indexPath.row];
    cell.titleLabel.text = album.title;
    cell.photoCountLabel.text = [NSString stringWithFormat:@"%ld", (unsigned long)album.photoCount];
    PHImageManager *imageManager = self.assembly.imageManager;
    if (cell.tag) {
        [imageManager cancelImageRequest:(PHImageRequestID)cell.tag];
    }
    CGSize size = cell.bounds.size;
    cell.tag = [imageManager requestImageForAsset:album.lastPhotoAsset targetSize:mrg_sizeInPixels(size) contentMode:PHImageContentModeAspectFit options:nil resultHandler:^(UIImage * _Nullable result, NSDictionary * _Nullable info) {
        cell.thumbnailView.image = result;
    }];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self performSegueWithIdentifier:kAlbumContentSegue sender:self];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:kAlbumContentSegue]) {
        MRGAlbumContentViewController *vc = segue.destinationViewController;
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        MRGAlbum *album = self.albums[indexPath.row];
        vc.album = album;
        vc.assembly = self.assembly;
    }
}

#pragma mark - Private 

- (void)setAlbums:(NSArray<MRGAlbum *> *)albums {
    _albums = albums;
    [self.tableView reloadData];
}

- (void)p_checkAuthorization {
    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusDenied) {
        [self mrg_showAccessDeniedAlertWithCompletion:^{
            exit(0);
        }];
    } else if (status == PHAuthorizationStatusNotDetermined) {
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (status == PHAuthorizationStatusAuthorized) {
                    [self p_updateData];
                } else if (status == PHAuthorizationStatusDenied) {
                    [self mrg_showAccessDeniedAlertWithCompletion:^{
                        exit(0);
                    }];
                }
            });
        }];
    } else if (status == PHAuthorizationStatusAuthorized) {
        [self p_updateData];
    }
}

- (void)p_setupViews {
    self.tableView.rowHeight = kRowHeight;
    self.tableView.tableFooterView = [UIView new];
    [self.tableView registerNib:[MRGAlbumCell nib] forCellReuseIdentifier:[MRGAlbumCell reuseIdentifier]];
}

- (void)p_updateData {
    id<MRGAlbumFetcher> albumFetcher = self.assembly.albumFetcher;
    [albumFetcher fetchAlbumsWithCompletion:^(NSArray<MRGAlbum *> *albums) {
        self.albums = albums;
    }];
}

@end
