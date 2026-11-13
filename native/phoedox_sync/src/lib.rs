//! Offline-capable document store for the Flutter app, built on yrs (Yjs in Rust).
//! Exposed to Dart via flutter_rust_bridge in a later step.

use yrs::updates::decoder::Decode;
use yrs::{Doc, GetString, ReadTxn, StateVector, Text, Transact, Update};

/// A shared document as used by all Phoedox document types.
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
        use yrs::updates::encoder::Encode;
        self.doc.transact().state_vector().encode_v1()
    }

    /// Applies an update from the server or another device.
    pub fn apply(&self, update: &[u8]) -> Result<(), String> {
        let u = Update::decode_v1(update).map_err(|e| e.to_string())?;
        self.doc.transact_mut().apply_update(u).map_err(|e| e.to_string())
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
}
