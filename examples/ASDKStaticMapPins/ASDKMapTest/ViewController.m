//
//  ViewController.m
//  ASDKMapTest
//
//  Created by Michal Ziman on 11/07/16.
//  Copyright © 2016 Michal Ziman. All rights reserved.
//

#import <AsyncDisplayKit/AsyncDisplayKit.h>

#import "ViewController.h"
#import "MTCustomMapAnnotation.h"

@interface ViewController ()
@property (nonatomic,strong) ASViewController *vc;
@property (nonatomic,strong) ASMapNode *mapNode;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    self.mapNode = [ASMapNode new];
    self.mapNode.backgroundColor = [UIColor greenColor];
    CLLocationCoordinate2D coordinates = CLLocationCoordinate2DMake(49.1954717, 16.6078803);
    self.mapNode.region = MKCoordinateRegionMakeWithDistance(coordinates, 20000, 20000);
    self.mapNode.mapDelegate = self;
    
    self.vc = [[ASViewController alloc] initWithNode:self.mapNode];
    [self.view addSubview:self.vc.view];
    
    [self addAnnotations];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)addAnnotations {
    
    MKPointAnnotation *brno = [MKPointAnnotation new];
    brno.coordinate = CLLocationCoordinate2DMake(49.2002211, 16.6078411);
    brno.title = @"Brno";
    
    MTCustomMapAnnotation *prigl = [MTCustomMapAnnotation new];
    prigl.coordinate = CLLocationCoordinate2DMake(49.2300883, 16.5163019);
    prigl.title = @"Prígl";
    prigl.image = [UIImage imageNamed:@"Water"];
    
    MTCustomMapAnnotation *kravak = [MTCustomMapAnnotation new];
    kravak.coordinate = CLLocationCoordinate2DMake(49.2031447, 16.5835942);
    kravak.title = @"Kravák";
    kravak.image = [UIImage imageNamed:@"Hill"];
    
    self.mapNode.annotations = @[brno, prigl, kravak];
}

#pragma mark MKMapViewDelegate methods

- (MKAnnotationView *)mapView:(MKMapView *)__unused mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    MKAnnotationView *av;
    if ([annotation isKindOfClass:[MTCustomMapAnnotation class]]) {
        av = [[MKAnnotationView alloc] init];
        av.center = CGPointMake(21, 21);
        av.image = [(MTCustomMapAnnotation *)annotation image];
    } else {
        av = [[MKPinAnnotationView alloc] initWithAnnotation:nil reuseIdentifier:@""];
    }
    
    av.opaque = NO;
    return av;
}

- (MKOverlayRenderer *)mapView:(MKMapView *)__unused mapView rendererForOverlay:(id<MKOverlay>)overlay
{
    MKOverlayRenderer *renderer = [[MKOverlayRenderer alloc] initWithOverlay:overlay];
    return renderer;
}


- (void)mapViewWillStartRenderingMap:(MKMapView *)mapView
{
}

- (void)mapViewDidFinishRenderingMap:(MKMapView *)mapView fullyRendered:(BOOL)__unused fullyRendered
{
}

@end
