#![allow(unused_must_use)]

use hash_db::Hasher;
use reference_trie::{
	NoExtensionLayout,
};
use trie_db::{
	DBValue, TrieDB, TrieDBMut, TrieLayout, TrieMut,
	proof::{generate_proof, verify_proof},
};
use std::env;
use hex::FromHex;

use std::fs;

use serde_derive::{Deserialize, Serialize};

type MemoryDB<H> = memory_db::MemoryDB<H, memory_db::HashKey<H>, DBValue>;

#[derive(Deserialize, Serialize, Debug)]
struct GeneratorResults {
    root: String,
    proof: Vec<String>,
    keys: Vec<String>,
    values: Vec<String>,
}

fn main() {
    let args: Vec<String> = env::args().collect();

    let mut current_exec_path = env::current_exe().unwrap();
    current_exec_path.pop();
    current_exec_path.pop();
    current_exec_path.pop();
    current_exec_path.push("results");
    let current_path = current_exec_path.display().to_string();

    if args[1] == "verify" {
        let root = <[u8; 32]>::from_hex(&args[2].trim_start_matches("0x")).unwrap();

        let mut proof = Vec::new();
        let mut i = 3;
        while args[i] != "items" {
            proof.push(hex::decode(args[i].clone().trim_start_matches("0x")).unwrap());
            i += 1;
        }

        if proof.len() == 0 {
            fs::write(current_path.clone() + "/verifierResults.json", "zero proof");
            return;
        }
        
        i += 1;
        let mut items = Vec::<(Vec<u8>, Option<Vec<u8>>)>::new();
        while i < args.len() - 1 {
            let value = hex::decode(&args[i+1].trim_start_matches("0x")).unwrap();
            if value.len() == 0 {
                items.push((hex::decode(args[i].clone().trim_start_matches("0x")).unwrap(), None));
            } else {
                items.push((hex::decode(args[i].clone().trim_start_matches("0x")).unwrap(), Some(value)));
            }
            i += 2;
        }

        if items.len() == 0 {
            fs::write(current_path.clone() + "/verifierResults.json", "zero items");
            return;
        }

        let output: String;
        match verify_proof::<NoExtensionLayout, _, _, _>(&root, &proof, items.iter()) {
            Ok(_) => output = "true".to_string(),
            Err(e) => output = e.to_string(),
        }
        fs::write(current_path.clone() + "/verifierResults.json", output);
    } else if args[1] == "generate" {
        let mut i = 2;
        let mut entries: Vec<(Vec<u8>, Vec<u8>)> = Vec::new();
        while args[i] != "keys"  {
            entries.push((hex::decode(args[i].clone().trim_start_matches("0x")).unwrap(), hex::decode(args[i+1].clone().trim_start_matches("0x")).unwrap()));
            i += 2;
        }

        i += 1;
        let mut keys: Vec<Vec<u8>> = Vec::new();
        let mut entries_to_prove = Vec::new();
        while i < args.len() {
            let index = args[i].clone().parse::<usize>().unwrap();
            entries_to_prove.push(entries[index].clone());
            keys.push(entries[index].0.clone());
            i += 1;
        }

        let (root, proof) = test_generate_proof::<NoExtensionLayout>(
            entries.clone(),
            keys.clone(),
        );

        // The solidity verifier requires the keys and values to be sorted
        entries_to_prove.sort();

        let mut proof_string = Vec::new();
        let mut keys_string = Vec::new();
        let mut values_string = Vec::new();

        for i in 0..proof.len() {
            proof_string.push(hex::encode(proof[i].clone()));
        }

        for i in 0..entries_to_prove.len() {
            keys_string.push(hex::encode(entries_to_prove[i].0.clone()));
            values_string.push(hex::encode(entries_to_prove[i].1.clone()));
        }

        let generator_results = GeneratorResults {
            root: hex::encode(root).to_owned(),
            proof: proof_string,
            keys: keys_string,
            values: values_string,
        };

        let result = serde_json::to_string(&generator_results).unwrap();

        match fs::write(current_path + "/generatorResults.json", result) {
            Ok(_) => print!("Successfully wrote to file"),
            Err(e) => panic!("Error writing to file: {}", e),
        }
    } else {
        panic!("Invalid command");
    }
    
}

fn test_generate_proof<L: TrieLayout>(
	entries: Vec<(Vec<u8>, Vec<u8>)>,
	keys: Vec<Vec<u8>>,
) -> (<L::Hash as Hasher>::Out, Vec<Vec<u8>>)
{
	// Populate DB with full trie from entries.
	let (db, root) = {
		let mut db = <MemoryDB<L::Hash>>::default();
		let mut root = Default::default();
		{
			let mut trie = <TrieDBMut<L>>::new(&mut db, &mut root);
            trie.insert(key, Some("")).unwrap();
			for (key, value) in entries.iter() {
				trie.insert(key, value).unwrap();
			}
		}
		(db, root)
	};

	// Generate proof for the given keys..
	let trie = <TrieDB<L>>::new(&db, &root).unwrap();

	let proof = generate_proof::<_, L, _, _>(&trie, keys.iter()).unwrap();

	(root, proof)
}
