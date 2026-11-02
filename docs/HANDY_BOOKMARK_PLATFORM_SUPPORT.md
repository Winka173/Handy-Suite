# Handy Bookmark platform support

| Capability                   | Android                         | iOS                                      | Windows                                | Web                                                     |
| ---------------------------- | ------------------------------- | ---------------------------------------- | -------------------------------------- | ------------------------------------------------------- |
| Offline save/organize/search | SQLite worker                   | SQLite worker source                     | SQLite worker, real tests              | IndexedDB source/static build                           |
| Incoming links               | System SEND/SEND_MULTIPLE queue | Embedded Share Extension/App Group queue | Paste/shortcuts/OLE URL-text drop      | POST Share Target on supporting installed PWAs          |
| Clipboard                    | Explicit button/shortcut        | Explicit button; OS privacy applies      | Explicit paste/Ctrl+V                  | Explicit paste; secure-context/browser policy           |
| Open original                | OS App Links/browser            | OS Universal Links/browser               | Default URL handler                    | Browser window/OS handling                              |
| Public metadata              | Bounded pinned native HTTP      | Same native adapter source               | Same native adapter                    | Unavailable: browser cannot enforce DNS/redirect policy |
| Reminders                    | Local OS notifications          | Local OS adapter source                  | In-app list                            | In-app list                                             |
| Ads/Pro                      | AdMob + Play native adapters    | AdMob + StoreKit source                  | Microsoft Store adapter, no mobile ads | Free; no fake web Pro verification                      |

Every platform has independent generated target/configuration. iOS has not been
built or executed on this Windows machine. Windows compiler tests do not prove
Explorer/browser drag delivery. Static Web/Node worker tests do not prove browser
runtime. Device/store evidence is recorded only after actual runs.

Installations do not automatically synchronize. Browser storage may be evicted;
export a portable backup. System share-sheet placement is controlled by each
source application and OS, not by Handy Bookmark.
