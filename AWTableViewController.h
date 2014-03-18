//
//  AWTableViewController.h
//  AWSyncEngine
//
//  Created by Anna Walser on 3/19/14.
//  Copyright (c) 2014 private. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AWTableViewController : UITableViewController <NSFetchedResultsControllerDelegate>


@property (nonatomic,strong) NSManagedObjectContext* managedObjectContext;
@property (nonatomic, retain) NSFetchedResultsController *fetchedResultsController;

@end
