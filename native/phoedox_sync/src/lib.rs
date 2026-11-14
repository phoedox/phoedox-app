//! Offline editing for the Phoedox app, built on yrs (Yjs in Rust), the same
//! CRDT the server and the web editor use.
//!
//! A page edited offline is merged when the device is back online: the text
//! the edit started from (base), the device's text (mine) and the current
//! text on the server (theirs) are replayed as Yjs edits from two clients,
//! so changes in different places all survive and nothing is overwritten.
//!
//! The C functions at the end are called from Dart via FFI (lib/sync).

use similar::{DiffOp, TextDiff};
use std::ffi::{c_char, CStr, CString};
use yrs::updates::decoder::Decode;
use yrs::updates::encoder::Encode;
use yrs::{ClientID, Doc, GetString, Options, ReadTxn, StateVector, Text, Transact, Update};

const FIELD: &str = "body";

/// A shared text document.
pub struct SyncDoc {
    doc: Doc,
}

impl Default for SyncDoc {
    fn default() -> Self {
        Self::new()
    }
}

impl SyncDoc {
    pub fn new() -> Self {
        Self { doc: Doc::new() }
    }

    fn with_client(id: u64) -> Self {
        Self { doc: Doc::with_options(Options { client_id: ClientID::new(id), ..Options::default() }) }
    }

    /// Inserts text into the named text field (used by tests and simple notes).
    pub fn insert_text(&self, field: &str, index: u32, chunk: &str) {
        let text = self.doc.get_or_insert_text(field);
        let mut txn = self.doc.transact_mut();
        text.insert(&mut txn, index, chunk);
    }

    pub fn text(&self, field: &str) -> String {
        let text = self.doc.get_or_insert_text(field);
        let txn = self.doc.transact();
        text.get_string(&txn)
    }

    /// Changes the field from its current text to `to` with the smallest
    /// edits (per character), like a person typing.
    pub fn edit_to(&self, field: &str, to: &str) {
        let from = self.text(field);
        let text = self.doc.get_or_insert_text(field);
        let mut txn = self.doc.transact_mut();
        let old: Vec<char> = from.chars().collect();
        let new: Vec<char> = to.chars().collect();
        // Byte offsets of every character of the old text (yrs counts bytes by default).
        let mut at = Vec::with_capacity(old.len() + 1);
        let mut b = 0u32;
        for c in &old {
            at.push(b);
            b += c.len_utf8() as u32;
        }
        at.push(b);
        let diff = TextDiff::from_chars(from.as_str(), to);
        // From the end, so earlier offsets stay valid.
        for op in diff.ops().iter().rev() {
            match *op {
                DiffOp::Equal { .. } => {}
                DiffOp::Delete { old_index, old_len, .. } => {
                    text.remove_range(&mut txn, at[old_index], at[old_index + old_len] - at[old_index]);
                }
                DiffOp::Insert { old_index, new_index, new_len } => {
                    let s: String = new[new_index..new_index + new_len].iter().collect();
                    text.insert(&mut txn, at[old_index], &s);
                }
                DiffOp::Replace { old_index, old_len, new_index, new_len } => {
                    text.remove_range(&mut txn, at[old_index], at[old_index + old_len] - at[old_index]);
                    let s: String = new[new_index..new_index + new_len].iter().collect();
                    text.insert(&mut txn, at[old_index], &s);
                }
            }
        }
    }

    /// Encodes all changes the other side has not seen yet.
    pub fn diff_since(&self, remote_state: &[u8]) -> Vec<u8> {
        let sv = if remote_state.is_empty() {
            StateVector::default()
        } else {
            StateVector::decode_v1(remote_state).unwrap_or_default()
        };
        self.doc.transact().encode_diff_v1(&sv)
    }

    pub fn state_vector(&self) -> Vec<u8> {
        self.doc.transact().state_vector().encode_v1()
    }

    /// Applies an update from the server or another device.
    pub fn apply(&self, update: &[u8]) -> Result<(), String> {
        let u = Update::decode_v1(update).map_err(|e| e.to_string())?;
        self.doc.transact_mut().apply_update(u).map_err(|e| e.to_string())
    }
}

/// Merges two texts that both started from `base`. Changes in different
/// places are all kept; where both changed the same place, both insertions
/// stay (the device's first) and deletions win.
pub fn merge3(base: &str, mine: &str, theirs: &str) -> String {
    if mine == base || mine == theirs {
        return theirs.to_string();
    }
    if theirs == base {
        return mine.to_string();
    }
    let origin = SyncDoc::with_client(1);
    origin.insert_text(FIELD, 0, base);
    let start = origin.diff_since(&[]);
    // Lower client ids sort first when two insert at the same place.
    let device = SyncDoc::with_client(2);
    let server = SyncDoc::with_client(3);
    for d in [&device, &server] {
        d.apply(&start).expect("own update");
    }
    device.edit_to(FIELD, mine);
    server.edit_to(FIELD, theirs);
    device.apply(&server.diff_since(&device.state_vector())).expect("own update");
    device.text(FIELD)
}

// ---- C interface for Dart -----------------------------------------------------

unsafe fn str_arg<'a>(p: *const c_char) -> &'a str {
    if p.is_null() {
        return "";
    }
    CStr::from_ptr(p).to_str().unwrap_or("")
}

/// Merges base/mine/theirs (UTF-8, NUL-terminated). The result must be
/// released with `phx_free_string`.
///
/// # Safety
/// All arguments must be valid NUL-terminated strings or null.
#[no_mangle]
pub unsafe extern "C" fn phx_merge3(base: *const c_char, mine: *const c_char, theirs: *const c_char) -> *mut c_char {
    let out = merge3(str_arg(base), str_arg(mine), str_arg(theirs));
    CString::new(out.replace('\0', "")).unwrap_or_default().into_raw()
}

/// Releases a string returned by this library.
///
/// # Safety
/// `s` must come from `phx_merge3` and be released only once.
#[no_mangle]
pub unsafe extern "C" fn phx_free_string(s: *mut c_char) {
    if !s.is_null() {
        drop(CString::from_raw(s));
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn offline_edits_merge() {
        let phone = SyncDoc::new();
        let server = SyncDoc::new();
        phone.insert_text("body", 0, "Router im Flur");
        server.apply(&phone.diff_since(&server.state_vector())).unwrap();

        // Both edit while the phone is offline.
        phone.insert_text("body", 14, " (Port 4)");
        server.insert_text("body", 0, "Hinweis: ");

        server.apply(&phone.diff_since(&server.state_vector())).unwrap();
        phone.apply(&server.diff_since(&phone.state_vector())).unwrap();
        assert_eq!(phone.text("body"), server.text("body"));
        assert_eq!(phone.text("body"), "Hinweis: Router im Flur (Port 4)");
    }

    #[test]
    fn edit_to_reaches_the_target() {
        let d = SyncDoc::new();
        d.insert_text("body", 0, "Grüße aus der Küche");
        for target in ["Grüße aus dem Keller", "", "ÄÖÜ 🧱 ok", "Grüße"] {
            d.edit_to("body", target);
            assert_eq!(d.text("body"), target);
        }
    }

    #[test]
    fn merge_keeps_both_sides() {
        let base = "# Router\n\nSteht im Flur.\n\nPort 4 ist frei.\n";
        let mine = "# Router\n\nSteht im Flur, oben links.\n\nPort 4 ist frei.\n";
        let theirs = "# Router\n\nSteht im Flur.\n\nPort 4 und 5 sind frei.\n";
        assert_eq!(merge3(base, mine, theirs), "# Router\n\nSteht im Flur, oben links.\n\nPort 4 und 5 sind frei.\n");
        // One side unchanged: the other wins as it is.
        assert_eq!(merge3(base, base, theirs), theirs);
        assert_eq!(merge3(base, mine, base), mine);
        // Both added at the same place: both stay, the device's text first.
        assert_eq!(merge3("ab", "aXb", "aYb"), "aXYb");
        // Umlauts and emoji survive.
        assert_eq!(merge3("Küche", "Küche 🍳", "Große Küche"), "Große Küche 🍳");
    }

    #[test]
    fn c_interface() {
        let s = |x: &str| CString::new(x).unwrap();
        let (b, m, t) = (s("eins zwei"), s("eins zwei drei"), s("null eins zwei"));
        unsafe {
            let out = phx_merge3(b.as_ptr(), m.as_ptr(), t.as_ptr());
            assert_eq!(CStr::from_ptr(out).to_str().unwrap(), "null eins zwei drei");
            phx_free_string(out);
            // Null counts as empty: nothing changed on the server, so the device's text wins.
            let out = phx_merge3(std::ptr::null(), m.as_ptr(), std::ptr::null());
            assert_eq!(CStr::from_ptr(out).to_str().unwrap(), "eins zwei drei");
            phx_free_string(out);
        }
    }
}
