/**
 * XCTest extensions for CGGeometry.
 *
 * Prefer these to XCTAssert(CGRectEqualToRect(...)) because you get output
 * that tells you what went wrong.
 * Could use NSValue, but using strings makes the description messages shorter.
 */

#import <XCTest/XCTestAssertionsImpl.h>

#define ASXCTAssertEqualSizes(s0, s1, ...) \
  _XCTPrimitiveAssertEqualObjects(self, NSStringFromCGSize(s0), @#s0, NSStringFromCGSize(s1), @#s1, __VA_ARGS__)

#define ASXCTAssertNotEqualSizes(s0, s1, ...) \
  _XCTPrimitiveAssertNotEqualObjects(self, NSStringFromCGSize(s0), @#s0, NSStringFromCGSize(s1), @#s1, __VA_ARGS__)

#define ASXCTAssertEqualPoints(p0, p1, ...) \
  _XCTPrimitiveAssertEqualObjects(self, NSStringFromCGPoint(p0), @#p0, NSStringFromCGPoint(p1), @#p1, __VA_ARGS__)

#define ASXCTAssertNotEqualPoints(p0, p1, ...) \
  _XCTPrimitiveAssertNotEqualObjects(self, NSStringFromCGPoint(p0), @#p0, NSStringFromCGPoint(p1), @#p1, __VA_ARGS__)

#define ASXCTAssertEqualRects(r0, r1, ...) \
  _XCTPrimitiveAssertEqualObjects(self, NSStringFromCGRect(r0), @#r0, NSStringFromCGRect(r1), @#r1, __VA_ARGS__)

#define ASXCTAssertNotEqualRects(r0, r1, ...) \
  _XCTPrimitiveAssertNotEqualObjects(self, NSStringFromCGRect(r0), @#r0, NSStringFromCGRect(r1), @#r1, __VA_ARGS__)

#define ASXCTAssertEqualDimensions(r0, r1, ...) \
  _XCTPrimitiveAssertEqualObjects(self, NSStringFromASDimension(r0), @#r0, NSStringFromASDimension(r1), @#r1, __VA_ARGS__)

#define ASXCTAssertNotEqualDimensions(r0, r1, ...) \
  _XCTPrimitiveAssertNotEqualObjects(self, NSStringFromASDimension(r0), @#r0, NSStringFromASDimension(r1), @#r1, __VA_ARGS__)

#define ASXCTAssertEqualSizeRanges(r0, r1, ...) \
  _XCTPrimitiveAssertEqualObjects(self, NSStringFromASSizeRange(r0), @#r0, NSStringFromASSizeRange(r1), @#r1, __VA_ARGS__)
