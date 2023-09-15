use daachorse::{
    charwise::{CharwiseDoubleArrayAhoCorasick, CharwiseDoubleArrayAhoCorasickBuilder},
    MatchKind,
};
use rustler::{Atom, Env, Error, ResourceArc, Term};

rustler::atoms! {
    ok,
    error,
    nil,
    leftmost_longest,
    leftmost_first,
    standard
}

struct TreeResource {
    pub match_kind: MatchKind,
    pub tree: Tree,
}

struct Tree {
    aho: CharwiseDoubleArrayAhoCorasick<usize>,
}

impl Tree {
    fn new(patterns: Vec<(&str, usize)>, match_kind: MatchKind) -> Self {
        let match_kind = MatchKind::from(match_kind);
        Self {
            aho: CharwiseDoubleArrayAhoCorasickBuilder::new()
                .match_kind(match_kind)
                .build_with_values(patterns)
                .unwrap(),
        }
    }
}

#[rustler::nif]
fn build_tree(
    patvals: Vec<(&str, usize)>,
    match_kind: Atom,
) -> Result<ResourceArc<TreeResource>, Error> {
    if match_kind == leftmost_longest() {
        return Ok(ResourceArc::new(TreeResource {
            match_kind: MatchKind::LeftmostLongest,
            tree: Tree::new(patvals, MatchKind::LeftmostLongest),
        }));
    } else if match_kind == leftmost_first() {
        return Ok(ResourceArc::new(TreeResource {
            match_kind: MatchKind::LeftmostFirst,
            tree: Tree::new(patvals, MatchKind::LeftmostFirst),
        }));
    } else if match_kind == standard() {
        return Ok(ResourceArc::new(TreeResource {
            match_kind: MatchKind::Standard,
            tree: Tree::new(patvals, MatchKind::Standard),
        }));
    } else {
        panic!("Invalid match_kind")
    }
}

#[rustler::nif]
fn leftmost_find_iter(
    resource: ResourceArc<TreeResource>,
    haystack: String,
) -> Vec<(usize, usize, usize)> {
    return resource
        .tree
        .aho
        .leftmost_find_iter(haystack)
        .map(|m| (m.start(), m.end(), m.value()))
        .collect();
}

#[rustler::nif]
fn find_overlapping_iter(
    resource: ResourceArc<TreeResource>,
    haystack: String,
) -> Vec<(usize, usize, usize)> {
    return resource
        .tree
        .aho
        .find_overlapping_iter(haystack)
        .map(|m| (m.start(), m.end(), m.value()))
        .collect();
}

#[rustler::nif]
fn find_iter(resource: ResourceArc<TreeResource>, haystack: String) -> Vec<(usize, usize, usize)> {
    return resource
        .tree
        .aho
        .find_iter(haystack)
        .map(|m| (m.start(), m.end(), m.value()))
        .collect();
}

#[rustler::nif]
fn get_match_kind(resource: ResourceArc<TreeResource>) -> Atom {
    match resource.match_kind {
        MatchKind::LeftmostLongest => return leftmost_longest(),
        MatchKind::LeftmostFirst => return leftmost_first(),
        MatchKind::Standard => return standard(),
    }
}

#[rustler::nif]
fn tree_heap_bytes(resource: ResourceArc<TreeResource>) -> usize {
    return resource.tree.aho.heap_bytes();
}

#[rustler::nif]
fn downcase(string: String) -> String {
    return string.to_lowercase()
}

fn load(env: Env, _info: Term) -> bool {
    rustler::resource!(TreeResource, env);
    true
}

rustler::init!(
    "Elixir.AhoCorasearch.Native",
    [
        build_tree,
        leftmost_find_iter,
        find_overlapping_iter,
        find_iter,
        get_match_kind,
        tree_heap_bytes,
        downcase

    ],
    load = load
);
