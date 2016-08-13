# Overview

There is an established pattern where UICollectionViewLayout talks directly to the collection view's delegate to get additional layout info e.g. the size of a header in a given section.

This pattern is established by Apple's flow layout, and it is used by Pinterest and I'm sure others. It is dangerous when used with ASDK because we update asynchronously, so
for instance if you delete a section from your data source, the layout won't find out until later and in the meantime it may ask the delegate about a section that doesn't exist!

The solution is to capture this kind of information from the data source immediately when a section is inserted, and make it available to the layout as we update the UICollectionView so that everyone is on the same page.

Enter: ASSectionInfo

## Usage During Layout

The collection view will make these section infos available in the same way that finished nodes are currently available.

#### [Sequence Diagram:][diag-layout-usage]

![][image-layout-usage]

## Creation When Inserting Sections

The section infos for any inserted/reloaded sections are queried synchronously, before the node blocks for their items. The top part of this diagram is the same as the current behavior but I think it's useful info =)

#### [Sequence Diagram:][diag-inserting-sections]

![][image-inserting-sections]

<!-- Reference -->
[diag-inserting-sections]: https://www.websequencediagrams.com/?lz=dGl0bGUgSW5zZXJ0aW5nL1JlbG9hZGluZyBTZWN0aW9ucwoKRGF0YSBTb3VyY2UtPkNWOiBpACoFABkIQXRJbmRleGVzOgpDVi0-Q2hhbmdlU2V0IAAzBUNvbnRyb2xsZXIAHRsAURFlbmRVcGRhdGVzADQgAB4MAGIYLT4AehFiZWdpbgAFNACBYxlsb29wIGZvciBlYWNoIHMAgjgGIGluZGV4CiAgIACBAhJDVjoAHwhJbmZvAIJABzoAKAVDVgCBLQcAgnEGAA8aAIMQDACDFwZSZXR1cm4gbmV3IEFTAIM-B0luZm8AUAgAgXoTABYdAIFKDml0ZW0gaW4AgVgIAIFVBQCBRRlub2RlQmxvY2sAhBwHUGF0aACBWgYAgU8VABEeAIFQGm9kZSBibG9jawBPDACBTBsAIg5lbmQKZW5kAIQRLQCFFAsAhFsQAIVlHACFBxsAhlMGCgCDFgoAg3EICgo&s=napkin
[image-inserting-sections]: https://www.websequencediagrams.com/cgi-bin/cdraw?lz=dGl0bGUgSW5zZXJ0aW5nL1JlbG9hZGluZyBTZWN0aW9ucwoKRGF0YSBTb3VyY2UtPkNWOiBpACoFABkIQXRJbmRleGVzOgpDVi0-Q2hhbmdlU2V0IAAzBUNvbnRyb2xsZXIAHRsAURFlbmRVcGRhdGVzADQgAB4MAGIYLT4AehFiZWdpbgAFNACBYxlsb29wIGZvciBlYWNoIHMAgjgGIGluZGV4CiAgIACBAhJDVjoAHwhJbmZvAIJABzoAKAVDVgCBLQcAgnEGAA8aAIMQDACDFwZSZXR1cm4gbmV3IEFTAIM-B0luZm8AUAgAgXoTABYdAIFKDml0ZW0gaW4AgVgIAIFVBQCBRRlub2RlQmxvY2sAhBwHUGF0aACBWgYAgU8VABEeAIFQGm9kZSBibG9jawBPDACBTBsAIg5lbmQKZW5kAIQRLQCFFAsAhFsQAIVlHACFBxsAhlMGCgCDFgoAg3EICgo&s=napkin
[image-layout-usage]: https://www.websequencediagrams.com/cgi-bin/cdraw?lz=dGl0bGUgcHJlcGFyZUxheW91dCAtIHNlY3Rpb24gbWV0cmljcwoKQ1YtPgAYBjoAHw4KbG9vcCBmb3IgZWFjaAAxCAogICAgCiAgICAATQYtPkNWOgBOCEluZm9BdEluZGV4OgAkBUNWLQBUClJldHVybiBQSU1hc29ucnlTACsKCgBFDQAOFDogY29sdW1uQ291bnQAgQAFADQUAFwSACYQAEYed2lkdGhPZkMAZgUAgUIIIHRvdGFsV2lkdGgAgVAGbm90ZSByaWdodCBvZgCCAQc6AIIJByBwYXNzZXMgY3VycmVudCBDVgCCYgkAgQsqAIECBQCCWA0AgxoIVXNlAIMyCWVuZAoKAIJ_BwCDAQYoT0spCg&s=napkin
[diag-layout-usage]: https://www.websequencediagrams.com/?lz=dGl0bGUgcHJlcGFyZUxheW91dCAtIHNlY3Rpb24gbWV0cmljcwoKQ1YtPgAYBjoAHw4KbG9vcCBmb3IgZWFjaAAxCAogICAgCiAgICAATQYtPkNWOgBOCEluZm9BdEluZGV4OgAkBUNWLQBUClJldHVybiBQSU1hc29ucnlTACsKCgBFDQAOFDogY29sdW1uQ291bnQAgQAFADQUAFwSACYQAEYed2lkdGhPZkMAZgUAgUIIIHRvdGFsV2lkdGgAgVAGbm90ZSByaWdodCBvZgCCAQc6AIIJByBwYXNzZXMgY3VycmVudCBDVgCCYgkAgQsqAIECBQCCWA0AgxoIVXNlAIMyCWVuZAoKAIJ_BwCDAQYoT0spCg&s=napkin
