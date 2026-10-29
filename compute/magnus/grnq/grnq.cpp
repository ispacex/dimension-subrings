// MATH-414 grnq: Z[H]/varpi^n for a finite p-group H = <x_1..x_r | rho_1..rho_s> (any presentation
// with gamma_n(F) <= N gamma_n... more precisely: Z[F/N]/varpi^n, so H may be given by the
// relators of its class-(n-1) quotient), modulo p^E, by a nilpotent quotient algorithm for the
// right module R_k = T/(J + T_{>=k}), T = Z<X_1..X_r>, x_i -> 1 + X_i, J the two-sided ideal of the
// rho - 1.  See README.md in this directory for the algorithm and its correctness argument.
//
// Input (stdin), whitespace separated:
//   p P  E E  n N  r R
//   let NAME expression   (any number; NAME then stands for the expression, shared)
//   rels S   then S expressions
//   tests T  then T lines: NAME expression
//   [spans S  then S lines: NAME k expr_1 .. expr_k]
// expression := g<i> (1-based) | (inv e) | (pow e INT) | (mul e e ...) | (comm e e)   [a,b] = a^-1 b^-1 a b
// Usage: grnq [n] < input   (n overrides the n of the input)
// Output: per stage the generators by weight and log_p |Delta^k / Delta^(k+1)|; the certificate;
// per test the largest d < n with h - 1 in Delta^d, or "in Delta^n".
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <string>
#include <vector>
#include <queue>
#include <algorithm>
#include <memory>
#include <chrono>
#include <map>
#include <cmath>
using namespace std;
typedef unsigned long long u64;
typedef __uint128_t u128;
typedef __int128 i128;

static int P, E, NDEG, R;
static int HMETH = 0;  // GRNQ_HOWELL: stream (default), fixed, dyn
static long long ST_ELIM = 0, ST_FILL = 0;  // Howell statistics: eliminations, entries written
static u64 D;
static vector<u64> PP;

static bool SMALLD = false;  // D < 2^32: products fit in 64 bits, Barrett reduction
static u64 BARM = 0;          // floor(2^64 / D)
static inline u64 modr(u64 x) { u64 q = (u64)(((u128)x * BARM) >> 64); u64 r = x - q * D; return r >= D ? r - D : r; }
static inline u64 mulm(u64 a, u64 b) { return SMALLD ? modr(a * b) : (u64)((u128)a * b % D); }
static inline u64 addm(u64 a, u64 b) { u64 c = a + b; return c >= D ? c - D : c; }
static inline u64 negm(u64 a) { return a ? D - a : 0; }
static int val(u64 a) { if (!a) return E; int v = 0; while (a % P == 0) { a /= P; v++; } return v; }
static u64 invunit(u64 a) {  // a coprime to p, inverse mod D
  i128 t = 0, nt = 1, r = (i128)D, nr = (i128)a;
  while (nr) { i128 q = r / nr, x; x = t - q * nt; t = nt; nt = x; x = r - q * nr; r = nr; nr = x; }
  if (r != 1) { fprintf(stderr, "invunit: not a unit\n"); exit(2); }
  if (t < 0) t += (i128)D;
  return (u64)t;
}
static u64 fromi128(i128 x) { i128 m = x % (i128)D; if (m < 0) m += (i128)D; return (u64)m; }
static double now() { return chrono::duration<double>(chrono::steady_clock::now().time_since_epoch()).count(); }

// sparse vector: sorted indices
struct SV { vector<int> i; vector<u64> v; size_t size() const { return i.size(); } };

// dense accumulator over [0, n)
struct Acc {
  vector<u64> a; vector<int> t; vector<char> m;
  void init(size_t n) { a.assign(n, 0); m.assign(n, 0); t.clear(); }
  void grow(size_t n) { if (a.size() < n) { a.resize(n, 0); m.resize(n, 0); } }
  inline void add(int k, u64 x) { if (!x) return; if (!m[k]) { m[k] = 1; t.push_back(k); } a[k] = addm(a[k], x); }
  void addsv(const SV& s, u64 c) { if (!c) return; for (size_t q = 0; q < s.size(); q++) add(s.i[q], mulm(s.v[q], c)); }
  SV take() {
    sort(t.begin(), t.end()); SV s;
    for (int k : t) { if (a[k]) { s.i.push_back(k); s.v.push_back(a[k]); } a[k] = 0; m[k] = 0; }
    t.clear(); return s;
  }
  void clear() { for (int k : t) { a[k] = 0; m[k] = 0; } t.clear(); }
};

// ---------------- expressions ----------------
struct Ex { int op; int g; long long n; vector<shared_ptr<Ex>> c; };  // op: 0 gen, 1 inv, 2 pow, 3 mul, 4 comm
typedef shared_ptr<Ex> PEx;
static string tok() {
  string s; int ch;
  while ((ch = getchar()) != EOF && (ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r')) {}
  if (ch == EOF) return s;
  if (ch == '(' || ch == ')') return string(1, (char)ch);
  s.push_back((char)ch);
  while ((ch = getchar()) != EOF && !(ch == ' ' || ch == '\n' || ch == '\t' || ch == '\r' || ch == '(' || ch == ')')) s.push_back((char)ch);
  if (ch == '(' || ch == ')') ungetc(ch, stdin);
  return s;
}
static vector<pair<string, PEx>> NAMES;  // let-bound subexpressions (a DAG: shared by pointer)
static PEx parse() {
  string t = tok();
  auto e = make_shared<Ex>();
  if (t.empty()) { fprintf(stderr, "parse: eof\n"); exit(2); }
  for (auto& nm : NAMES) if (nm.first == t) return nm.second;
  if (t[0] == 'g') { e->op = 0; e->g = atoi(t.c_str() + 1) - 1; if (e->g < 0 || e->g >= R) { fprintf(stderr, "bad gen %s\n", t.c_str()); exit(2); } return e; }
  if (t != "(") { fprintf(stderr, "parse: unexpected %s\n", t.c_str()); exit(2); }
  string op = tok();
  if (op == "inv") { e->op = 1; e->c.push_back(parse()); }
  else if (op == "pow") { e->op = 2; e->c.push_back(parse()); e->n = atoll(tok().c_str()); }
  else if (op == "mul") { e->op = 3; }
  else if (op == "comm") { e->op = 4; }
  else { fprintf(stderr, "parse: op %s\n", op.c_str()); exit(2); }
  if (e->op >= 3) {
    for (;;) { int ch; while ((ch = getchar()) == ' ' || ch == '\n' || ch == '\t' || ch == '\r') {}
      if (ch == ')') { ungetc(ch, stdin); break; } ungetc(ch, stdin); e->c.push_back(parse()); }
    if (e->op == 4 && e->c.size() != 2) { fprintf(stderr, "comm needs 2\n"); exit(2); }
  }
  if (tok() != ")") { fprintf(stderr, "parse: missing )\n"); exit(2); }
  return e;
}
// binomial(e, t) mod D, e any integer, t < NDEG (exact in 128 bits for |e| < 2^20)
static u64 binom(long long e, int t) {
  i128 c = 1;
  for (int q = 0; q < t; q++) { c = c * (i128)(e - q); c /= (q + 1); }
  return fromi128(c);
}

// ---------------- the free algebra T_{<n} (Magnus coefficients of the relators) ----------------
struct FreeT {
  vector<long long> off;  // off[d] = index of the first word of length d
  vector<long long> rp;   // R^d
  long long size;
  FreeT() { off.assign(NDEG + 1, 0); rp.assign(NDEG + 1, 1); for (int d = 0; d < NDEG; d++) { off[d + 1] = off[d] + rp[d]; rp[d + 1] = rp[d] * R; } size = off[NDEG]; }
  typedef vector<u64> V;
  // truncated product: word u of length du times word v of length dv -> u v
  V mul(const V& a, const V& b) const {
    V c(size, 0);
    for (int du = 0; du < NDEG; du++) for (long long iu = 0; iu < rp[du]; iu++) {
      u64 x = a[off[du] + iu]; if (!x) continue;
      for (int dv = 0; du + dv < NDEG; dv++) {
        long long base = off[du + dv] + iu * rp[dv];
        const u64* bv = &b[off[dv]];
        for (long long iv = 0; iv < rp[dv]; iv++) if (bv[iv]) c[base + iv] = addm(c[base + iv], mulm(x, bv[iv]));
      }
    }
    return c;
  }
  V one() const { V c(size, 0); c[0] = 1; return c; }
  int deg(long long k) const { int d = 0; while (off[d + 1] <= k) d++; return d; }
  // h^e = sum_t binomial(e, t) (h - 1)^t
  V power(const V& h, long long e) const {
    V d = h; d[0] = (d[0] + D - 1) % D;
    V acc = one(), dp = one();
    for (int t = 1; t < NDEG; t++) {
      dp = mul(dp, d); u64 c = binom(e, t); if (!c) continue;
      for (long long q = 0; q < size; q++) if (dp[q]) acc[q] = addm(acc[q], mulm(dp[q], c));
    }
    return acc;
  }
  map<const Ex*, V> memo;
  const V& magnus(const PEx& h) {
    auto it = memo.find(h.get()); if (it != memo.end()) return it->second;
    V r;
    switch (h->op) {
      case 0: r = one(); r[off[1] + h->g] = 1; break;
      case 1: r = power(magnus(h->c[0]), -1); break;
      case 2: r = power(magnus(h->c[0]), h->n); break;
      case 3: r = one(); for (auto& c : h->c) r = mul(r, magnus(c)); break;
      case 4: { const V& a = magnus(h->c[0]); const V& b = magnus(h->c[1]);
        r = mul(mul(power(a, -1), power(b, -1)), mul(a, b)); break; }
    }
    return memo[h.get()] = r;
  }
};

// ---------------- the presentation of R_k ----------------
struct Pres {
  int ngen = 1;
  vector<int> wt{0}, ex{0};       // ex[b] = e_b, or E (no power relation)
  vector<SV> pi{SV()};            // p^e_b b = pi_b (later generators)
  vector<vector<SV>> mu{vector<SV>(0)};  // b X_j = mu[b][j]
  // the slot each generator of weight >= 1 was created from: product (defb, defj) or the power
  // relation of defb (defj = -1).  A defining slot gets no tail later: the generator absorbs it.
  vector<int> defb{-1}, defj{-1};
  vector<vector<char>> isdefX{vector<char>(0)}; vector<char> isdefP{0};
};
static Pres PR;
// tail columns during a stage (indices >= ngen in the combined space)
static vector<int> tailP;            // per generator, column or -1
static vector<vector<int>> tailX;    // per generator, per letter
static int NT;                       // number of tails

// combined-space module for one stage: gens [0, ngen) then tails
struct StageMod {
  Acc acc;
  StageMod() { acc.init(PR.ngen + NT); }
  // normal form of acc: reduce the generator part by the power relations (with their tails), in order
  SV nf_acc() {
    priority_queue<int, vector<int>, greater<int>> pq;
    for (int k : acc.t) if (k < PR.ngen) pq.push(k);
    int last = -1;
    while (!pq.empty()) {
      int b = pq.top(); pq.pop(); if (b == last) continue; last = b;
      u64 a = acc.a[b]; if (!a || PR.ex[b] >= E) continue;
      u64 q = a / PP[PR.ex[b]]; if (!q) continue;
      acc.a[b] = a % PP[PR.ex[b]];
      const SV& s = PR.pi[b];
      for (size_t t = 0; t < s.size(); t++) { int c = s.i[t]; if (!acc.m[c] || !acc.a[c]) pq.push(c); acc.add(c, mulm(s.v[t], q)); }
      if (tailP.size() && tailP[b] >= 0) acc.add(tailP[b], q);
    }
    return acc.take();
  }
  SV nf(const SV& v) { acc.addsv(v, 1); return nf_acc(); }
  SV mulX(const SV& v, int j) {
    for (size_t q = 0; q < v.size(); q++) {
      int c = v.i[q]; if (c >= PR.ngen) continue;  // tails . X = 0
      acc.addsv(PR.mu[c][j], v.v[q]);
      if (tailX.size() && tailX[c][j] >= 0) acc.add(tailX[c][j], v.v[q]);
    }
    return nf_acc();
  }
};

// ---------------- sparse Howell form over Z/p^E ----------------
struct Row { vector<int> i; vector<u64> v; };
static int lead(const Row& r) { return r.i.empty() ? INT32_MAX : r.i[0]; }
static void scale(Row& r, u64 c) { size_t w = 0; for (size_t q = 0; q < r.i.size(); q++) { u64 x = mulm(r.v[q], c); if (x) { r.i[w] = r.i[q]; r.v[w++] = x; } } r.i.resize(w); r.v.resize(w); }
static Row axpy(const Row& a, const Row& b, u64 cb) {  // a + cb b
  Row s; size_t p = 0, q = 0; s.i.reserve(a.i.size() + b.i.size()); s.v.reserve(a.i.size() + b.i.size());
  while (p < a.i.size() || q < b.i.size()) {
    int k; u64 x;
    if (q >= b.i.size() || (p < a.i.size() && a.i[p] < b.i[q])) { k = a.i[p]; x = a.v[p++]; }
    else if (p >= a.i.size() || b.i[q] < a.i[p]) { k = b.i[q]; x = mulm(b.v[q++], cb); }
    else { k = a.i[p]; x = addm(a.v[p++], mulm(b.v[q++], cb)); }
    if (x) { s.i.push_back(k); s.v.push_back(x); }
  }
  return s;
}
// Howell form in the fixed column order 0..ncol-1 (the p^(E-v) multiple of each pivot row is added back);
// returns pivot rows indexed by pivot column (empty Row if none), entry p^v at the pivot
static vector<Row> howell_fixed(vector<Row>& rows, int ncol, vector<int>& pv, vector<int>& order) {
  vector<vector<Row>> bucket(ncol);
  for (auto& r : rows) if (!r.i.empty()) bucket[lead(r)].push_back(std::move(r));
  rows.clear();
  vector<Row> piv(ncol); pv.assign(ncol, -1);
  for (int c = 0; c < ncol; c++) {
    auto& B = bucket[c]; if (B.empty()) continue;
    size_t best = 0; int bv = E + 1;
    for (size_t q = 0; q < B.size(); q++) { int v = val(B[q].v[0]); if (v < bv || (v == bv && B[q].i.size() < B[best].i.size())) { bv = v; best = q; } }
    Row pr = std::move(B[best]); B.erase(B.begin() + best);
    u64 u = pr.v[0] / PP[bv]; scale(pr, invunit(u));  // pivot entry p^bv
    for (auto& r : B) {
      u64 q = r.v[0] / PP[bv];  // r.v[0] = p^v' unit with v' >= bv
      Row s = axpy(r, pr, negm(q)); ST_ELIM++; ST_FILL += s.i.size();
      if (!s.i.empty()) bucket[lead(s)].push_back(std::move(s));
    }
    vector<Row>().swap(B);
    if (bv > 0) { Row s = pr; scale(s, PP[E - bv]); if (!s.i.empty()) bucket[lead(s)].push_back(std::move(s)); }
    pv[c] = bv; piv[c] = std::move(pr);
  }
  order.clear(); for (int c = 0; c < ncol; c++) order.push_back(c);
  return piv;
}

// Howell form in the fixed column order, inserting the rows one by one into a dense accumulator (only the
// pivot rows are kept: the rows of a stage need not fit in memory once they are dense).  A row is reduced
// at each column where it has an entry and a pivot of no larger valuation exists; if its valuation there
// is smaller, it becomes the pivot and the old pivot row is inserted again; a new pivot row p^v r adds
// p^(E-v) r to the queue (the Howell closure).  Each column's pivot then has the least valuation among
// the lattice elements leading there, and the closure rows give the Howell property.
static vector<Row> howell_stream(vector<Row>& rows, int ncol, vector<int>& pv, vector<int>& order) {
  vector<Row> piv(ncol); pv.assign(ncol, -1);
  vector<u64> acc(ncol, 0);
  vector<Row> pend; size_t next = 0;
  auto extract = [&](int c, int hi, u64 u) {  // acc[c..hi] times u as a row; clears acc
    Row r; for (int k = c; k <= hi; k++) if (acc[k]) { r.i.push_back(k); r.v.push_back(mulm(acc[k], u)); acc[k] = 0; }
    return r;
  };
  auto closure = [&](const Row& r, int v) { if (v > 0) { Row s = r; scale(s, PP[E - v]); if (!s.i.empty()) pend.push_back(std::move(s)); } };
  for (;;) {
    Row x;
    if (!pend.empty()) { x = std::move(pend.back()); pend.pop_back(); }
    else if (next < rows.size()) { x = std::move(rows[next++]); }
    else break;
    if (x.i.empty()) continue;
    for (size_t q = 0; q < x.i.size(); q++) acc[x.i[q]] = x.v[q];
    int c = x.i[0], hi = x.i.back();
    while (c <= hi) {
      u64 a = acc[c];
      if (!a) { c++; continue; }
      int va = val(a);
      if (pv[c] < 0 || va < pv[c]) {
        Row r = extract(c, hi, invunit(a / PP[va]));
        if (pv[c] >= 0) pend.push_back(std::move(piv[c]));
        pv[c] = va; closure(r, va); piv[c] = std::move(r);
        break;
      }
      u64 nq = negm(a / PP[pv[c]]); const Row& pr = piv[c]; ST_ELIM++; ST_FILL += pr.i.size();
      for (size_t t = 0; t < pr.i.size(); t++) { int k = pr.i[t]; acc[k] = addm(acc[k], mulm(pr.v[t], nq)); if (k > hi) hi = k; }
      c++;
    }
  }
  rows.clear(); rows.shrink_to_fit();
  order.clear(); for (int c = 0; c < ncol; c++) order.push_back(c);
  return piv;
}

// Howell form with a dynamic pivot order (Markowitz-like), over columns [0, ncol).  Phase v = 0, 1, ...:
// every remaining entry has valuation >= v; a pivot is an entry of valuation exactly v (shortest row
// first, then the column in fewest rows), normalised to p^v, and its column is cleared from all other
// rows (exact: their entries there have valuation >= v).  Then the rows left span exactly the elements
// of the lattice vanishing on the pivot columns (the multiple p^(E-v) of a pivot row, which the
// fixed-order Howell form adds, is 0 here, as all its entries have valuation >= v).  So in the order
// 'order' (pivot columns as chosen, then the columns without pivot) the pivot rows are triangular and
// reduction by them in that order decides membership.  piv[c] holds the row (sorted by column) with
// entry p^pv[c] at c; pv[c] = -1 for a column without pivot.
static vector<Row> howell_dyn(vector<Row>& rows, int ncol, vector<int>& pv, vector<int>& order) {
  int nr = rows.size();
  vector<char> alive(nr, 1), colpiv(ncol, 0);
  vector<vector<int>> colrows(ncol);
  for (int r = 0; r < nr; r++) { if (rows[r].i.empty()) alive[r] = 0; for (int c : rows[r].i) colrows[c].push_back(r); }
  vector<Row> piv(ncol); pv.assign(ncol, -1); order.clear();
  auto getv = [&](const Row& r, int c) -> u64 { auto it = lower_bound(r.i.begin(), r.i.end(), c); return (it != r.i.end() && *it == c) ? r.v[it - r.i.begin()] : 0; };
  for (int v = 0; v < E; v++) {
    auto hasv = [&](const Row& r) { for (u64 x : r.v) if (val(x) == v) return true; return false; };
    priority_queue<pair<size_t, int>, vector<pair<size_t, int>>, greater<pair<size_t, int>>> pq;
    for (int r = 0; r < nr; r++) if (alive[r] && hasv(rows[r])) pq.push({rows[r].i.size(), r});
    while (!pq.empty()) {
      auto [len, r] = pq.top(); pq.pop();
      if (!alive[r] || rows[r].i.size() != len) continue;
      int bc = -1; size_t bcnt = SIZE_MAX; u64 bx = 0;
      for (size_t q = 0; q < rows[r].i.size(); q++) if (val(rows[r].v[q]) == v) { int c = rows[r].i[q]; if (colrows[c].size() < bcnt) { bcnt = colrows[c].size(); bc = c; bx = rows[r].v[q]; } }
      if (bc < 0) continue;
      Row pr = std::move(rows[r]); alive[r] = 0;
      scale(pr, invunit(bx / PP[v]));
      vector<int> lst; lst.swap(colrows[bc]);
      for (int rr : lst) {
        if (rr == r || !alive[rr]) continue;
        u64 a = getv(rows[rr], bc); if (!a) continue;
        const Row& x = rows[rr]; u64 cb = negm(a / PP[v]);
        Row y; y.i.reserve(x.i.size() + pr.i.size()); y.v.reserve(x.i.size() + pr.i.size());
        size_t p1 = 0, p2 = 0;
        while (p1 < x.i.size() || p2 < pr.i.size()) {
          int k; u64 z;
          if (p2 >= pr.i.size() || (p1 < x.i.size() && x.i[p1] < pr.i[p2])) { k = x.i[p1]; z = x.v[p1++]; }
          else if (p1 >= x.i.size() || pr.i[p2] < x.i[p1]) { k = pr.i[p2]; z = mulm(pr.v[p2++], cb); if (z) colrows[k].push_back(rr); }
          else { k = x.i[p1]; z = addm(x.v[p1++], mulm(pr.v[p2++], cb)); }
          if (z) { y.i.push_back(k); y.v.push_back(z); }
        }
        ST_ELIM++; ST_FILL += y.i.size();
        rows[rr] = std::move(y);
        if (rows[rr].i.empty()) alive[rr] = 0; else if (hasv(rows[rr])) pq.push({rows[rr].i.size(), rr});
      }
      colpiv[bc] = 1; pv[bc] = v; order.push_back(bc); piv[bc] = std::move(pr);
    }
  }
  for (int r = 0; r < nr; r++) if (alive[r] && !rows[r].i.empty()) { fprintf(stderr, "howell_dyn: row left over\n"); exit(3); }
  for (int c = 0; c < ncol; c++) if (!colpiv[c]) order.push_back(c);
  rows.clear();
  return piv;
}

// ---------------- one stage: R_k -> R_{k+1} ----------------
static vector<vector<u64>> magnus;  // per relator, dense over the words of T_{<n}
static vector<char> live;           // word has a nonzero coefficient in some relator, in itself or below
static FreeT* FT;
static vector<char> subtree_nz(const vector<vector<u64>>& cs) {
  vector<char> nz(FT->size, 0);
  for (long long q = FT->size - 1; q >= 0; q--) {
    for (auto& c : cs) if (c[q]) { nz[q] = 1; break; }
    int d = FT->deg(q); if (nz[q] || d + 1 >= NDEG) continue;
    long long c0 = FT->off[d + 1] + (q - FT->off[d]) * R;
    for (int j = 0; j < R; j++) if (nz[c0 + j]) { nz[q] = 1; break; }
  }
  return nz;
}

struct DFSCtx { StageMod* sm; vector<Acc>* res; int k; int wb; };
static void dfs(DFSCtx& C, const SV& u, int d, long long widx) {
  int ns = magnus.size();
  for (int s = 0; s < ns; s++) { u64 c = magnus[s][widx]; if (c) (*C.res)[s].addsv(u, c); }
  if (C.wb + d >= C.k) return;  // children have weight > k
  bool hasgen = false; for (int x : u.i) if (x < PR.ngen) { hasgen = true; break; }
  if (!hasgen) return;
  if (d + 1 >= NDEG) return;
  for (int j = 0; j < R; j++) {
    long long cidx = FT->off[d + 1] + (widx - FT->off[d]) * R + j;
    if (!live[cidx]) continue;
    SV ch = C.sm->mulX(u, j);
    if (!ch.size()) continue;
    dfs(C, ch, d + 1, cidx);
  }
}

// Projection test at the last stage (GRNQ_PROJ=r), k = n - 1.  Every tail is an element of
// Delta^k/Delta^(k+1), which Delta kills on both sides, so the subgroup W spanned by any set of tails is a
// two-sided ideal and R_(k+1)/W a quotient ring: h - 1 nonzero there proves h - 1 notin Delta^(k+1).  W
// is spanned by the tails outside a chosen set S, so the rows are needed on S only.  The walk of (E2) uses
// the linear action (no normal form per node; the action is linear on the free module); per generator b
// and relator the generator part and the tails on S are summed, and one normal form at the end supplies the
// power tails of the carries.  h - 1 = 0 in R/W iff its vector y|S lies in the span of the restricted rows.
// S = the support of y, enlarged r times by the supports of the rows meeting S.  A y|S in the span decides
// nothing.
static int PROJ = -1;
static vector<string> PROJ_N; static vector<PEx> PROJ_T;
static vector<Row> howell_stream(vector<Row>& rows, int ncol, vector<int>& pv, vector<int>& order);
static vector<Row> howell_fixed(vector<Row>& rows, int ncol, vector<int>& pv, vector<int>& order);

// the walk of (E2) by the linear action: for the words m below the node (gen part g of b . m), adds
// coef[s][m] (b . m) to rg[s] (generator part) and rt[s] (tails on mask)
static void lin_walk(const SV& g, int d, long long widx, const vector<vector<u64>>& coef, const vector<char>& lv,
                     const vector<char>& mask, int ng, vector<Acc>& rg, vector<Acc>& rt, vector<Acc>& tg, vector<Acc>& tt) {
  if (d + 1 >= NDEG) return;
  for (int j = 0; j < R; j++) {
    long long cidx = FT->off[d + 1] + (widx - FT->off[d]) * R + j;
    if (!lv[cidx]) continue;
    for (size_t q = 0; q < g.size(); q++) {
      int c = g.i[q]; u64 a = g.v[q];
      tg[d].addsv(PR.mu[c][j], a);
      int t = tailX[c][j]; if (t >= 0 && mask[t - ng]) tt[d].add(t - ng, a);
    }
    SV cg = tg[d].take(), ct = tt[d].take();
    for (size_t s = 0; s < coef.size(); s++) { u64 cc = coef[s][cidx]; if (cc) { rg[s].addsv(cg, cc); rt[s].addsv(ct, cc); } }
    if (cg.size()) lin_walk(cg, d + 1, cidx, coef, lv, mask, ng, rg, rt, tg, tt);
  }
}

static void final_proj(int k, int ng) {
  StageMod sm;
  vector<Acc> tg(NDEG), tt(NDEG); for (auto& a : tg) a.init(ng); for (auto& a : tt) a.init(NT);
  long long badgen = 0;
  // normal form of (generator part g, tails t on mask); returns the tails on mask, as a row
  auto finish = [&](const SV& g, const SV& t, const vector<char>& mask) {
    sm.acc.addsv(g, 1); for (size_t q = 0; q < t.size(); q++) sm.acc.add(ng + t.i[q], t.v[q]);
    SV x = sm.nf_acc(); Row r;
    for (size_t q = 0; q < x.size(); q++) { if (x.i[q] < ng) { badgen++; continue; } int c = x.i[q] - ng; if (mask[c]) { r.i.push_back(c); r.v.push_back(x.v[q]); } }
    return r;
  };
  vector<Acc> rg(magnus.size()), rt(magnus.size()); for (auto& a : rg) a.init(ng); for (auto& a : rt) a.init(NT);
  // rows (E0), (E1), (E2) of generator b, on mask
  auto rows_of_b = [&](int b, const vector<char>& mask, vector<Row>& out, bool local = true) {
    size_t r0 = out.size();
    if (PR.ex[b] < E) {
      { Acc& a = tt[0]; if (tailP[b] >= 0 && mask[tailP[b] - ng]) a.add(tailP[b] - ng, PP[E - PR.ex[b]]);
        SV pg = PR.pi[b]; for (auto& v : pg.v) v = mulm(v, PP[E - PR.ex[b]]);
        Row r = finish(pg, a.take(), mask); if (!r.i.empty()) out.push_back(std::move(r)); }
      for (int j = 0; j < R; j++) {
        Acc& ag = tg[0]; Acc& a = tt[0]; u64 pe = PP[PR.ex[b]];
        ag.addsv(PR.mu[b][j], pe); int t = tailX[b][j]; if (t >= 0 && mask[t - ng]) a.add(t - ng, pe);
        for (size_t q = 0; q < PR.pi[b].size(); q++) { int c = PR.pi[b].i[q]; u64 m = negm(PR.pi[b].v[q]);
          ag.addsv(PR.mu[c][j], m); int tc = tailX[c][j]; if (tc >= 0 && mask[tc - ng]) a.add(tc - ng, m); }
        Row r = finish(ag.take(), a.take(), mask); if (!r.i.empty()) out.push_back(std::move(r));
      }
    }
    SV g; g.i.push_back(b); g.v.push_back(1);
    lin_walk(g, 0, 0, magnus, live, mask, ng, rg, rt, tg, tt);
    for (size_t s = 0; s < magnus.size(); s++) { Row r = finish(rg[s].take(), rt[s].take(), mask); if (!r.i.empty()) out.push_back(std::move(r)); }
    if (local && out.size() - r0 > 1) {  // local Howell of the rows of b
      vector<int> cols; for (size_t q = r0; q < out.size(); q++) cols.insert(cols.end(), out[q].i.begin(), out[q].i.end());
      sort(cols.begin(), cols.end()); cols.erase(unique(cols.begin(), cols.end()), cols.end());
      vector<Row> loc(out.begin() + r0, out.end()); out.resize(r0);
      for (auto& r : loc) for (auto& c : r.i) c = lower_bound(cols.begin(), cols.end(), c) - cols.begin();
      vector<int> lpv, lord; vector<Row> lp = howell_fixed(loc, cols.size(), lpv, lord);
      for (auto& r : lp) { if (r.i.empty()) continue; for (auto& c : r.i) c = cols[c]; out.push_back(std::move(r)); }
    }
  };
  vector<char> all(NT, 1);
  printf("projection test at stage %d: %d tails\n", k, NT);
  for (size_t s = 0; s < PROJ_T.size(); s++) {
    double t0 = now();
    vector<vector<u64>> c1(1, FT->magnus(PROJ_T[s])); c1[0][0] = (c1[0][0] + D - 1) % D;
    vector<char> lv1 = subtree_nz(c1);
    vector<Acc> yg(1), yt(1); yg[0].init(ng); yt[0].init(NT);
    SV g0; g0.i.push_back(0); g0.v.push_back(1);
    lin_walk(g0, 0, 0, c1, lv1, all, ng, yg, yt, tg, tt);
    // h - 1 itself: its generator part, in normal form, must vanish (h in D_k); else its weight is known
    sm.acc.addsv(yg[0].take(), 1); { SV tl = yt[0].take(); for (size_t q = 0; q < tl.size(); q++) sm.acc.add(ng + tl.i[q], tl.v[q]); }
    SV x = sm.nf_acc(); SV y; int wmin = NDEG;
    for (size_t q = 0; q < x.size(); q++) { if (x.i[q] < ng) wmin = min(wmin, PR.wt[x.i[q]]); else { y.i.push_back(x.i[q] - ng); y.v.push_back(x.v[q]); } }
    if (wmin < NDEG) { printf("test %s: h - 1 in Delta^%d, not in Delta^%d\n", PROJ_N[s].c_str(), wmin, wmin + 1); continue; }
    if (!y.size()) { printf("test %s: y = 0: h - 1 in Delta^%d\n", PROJ_N[s].c_str(), NDEG); continue; }
    vector<char> inS(NT, 0); for (int c : y.i) inS[c] = 1;
    vector<Row> rows;
    for (int r = 0; r <= PROJ; r++) {
      rows.clear();
      vector<int> touch;  // generators whose rows meet S
      for (int b = 0; b < ng; b++) { size_t r0 = rows.size(); rows_of_b(b, inS, rows); if (rows.size() > r0) touch.push_back(b); }
      long long ns = count(inS.begin(), inS.end(), 1);
      printf("  test %s, round %d: |S| = %lld, %zu rows from %zu generators (%.1f s)\n", PROJ_N[s].c_str(), r, ns, rows.size(), touch.size(), now() - t0);
      fflush(stdout);
      if (r == PROJ) break;
      // the supports of the full rows of these generators, one generator at a time (all of them at once
      // do not fit in memory; the Howell rows of b have support in that of its rows)
      for (int b : touch) { vector<Row> full; rows_of_b(b, all, full, false); for (auto& rr : full) for (int c : rr.i) inS[c] = 1; }
    }
    if (badgen) { printf("ERROR: %lld nonzero generator entries in the rows (R_k inconsistent)\n", badgen); exit(3); }
    vector<int> S, pos(NT, -1); for (int c = 0; c < NT; c++) if (inS[c]) { pos[c] = S.size(); S.push_back(c); }
    for (auto& rr : rows) for (auto& c : rr.i) c = pos[c];
    size_t nr = rows.size();
    vector<int> pv, order; vector<Row> piv = howell_stream(rows, S.size(), pv, order);
    vector<u64> a(S.size(), 0); for (size_t q = 0; q < y.size(); q++) if (pos[y.i[q]] >= 0) a[pos[y.i[q]]] = y.v[q];
    bool inspan = true;
    for (size_t c = 0; c < S.size(); c++) {
      if (!a[c]) continue;
      int va = val(a[c]);
      if (pv[c] < 0 || va < pv[c]) { inspan = false; break; }
      u64 nq = negm(a[c] / PP[pv[c]]);
      for (size_t t = 0; t < piv[c].i.size(); t++) { int kk = piv[c].i[t]; a[kk] = addm(a[kk], mulm(piv[c].v[t], nq)); }
    }
    printf("test %s: y has %zu entries; |S| = %zu, %zu rows; %s (%.1f s)\n", PROJ_N[s].c_str(), y.size(), S.size(), nr,
           inspan ? "y|S in the span: undecided" : "y|S NOT in the span: h - 1 notin Delta^n (exact)", now() - t0);
    fflush(stdout);
  }
}

static bool stage(int k) {  // PR = R_k (generators of weight <= k-1) -> R_{k+1}; true: stopped after the projection test
  double t0 = now();
  int ng = PR.ngen;
  tailP.assign(ng, -1); tailX.assign(ng, vector<int>(R, -1)); NT = 0;
  // order: power tails and tails of lower products first, candidates (weight k-1) last
  vector<int> slotb, slotj;  // slot of each tail column (j = -1: power)
  auto newtail = [&](int b, int j) { slotb.push_back(b); slotj.push_back(j); return ng + NT++; };
  for (int b = 0; b < ng; b++) {
    if (PR.ex[b] < E && !PR.isdefP[b]) tailP[b] = newtail(b, -1);
    if (PR.wt[b] < k - 1) for (int j = 0; j < R; j++) if (!PR.isdefX[b][j]) tailX[b][j] = newtail(b, j);
  }
  for (int b = 0; b < ng; b++) if (PR.wt[b] == k - 1) for (int j = 0; j < R; j++) if (!PR.isdefX[b][j]) tailX[b][j] = newtail(b, j);
  if (PROJ >= 0 && k == NDEG - 1) { final_proj(k, ng); return true; }
  StageMod sm;
  vector<Row> rows;
  long long badgen = 0;
  auto push = [&](const SV& s) {
    Row r;
    for (size_t q = 0; q < s.size(); q++) { if (s.i[q] < ng) { badgen++; continue; } r.i.push_back(s.i[q] - ng); r.v.push_back(s.v[q]); }
    if (!r.i.empty()) rows.push_back(std::move(r));
  };
  // (E0) p^(E-e_b) (pi_b + t^P_b) = 0: over Z/p^E the power relation p^e_b b = pi_b + t^P_b implies it,
  // as p^E b = 0 (the Howell closure of the presentation; without it a relation such as
  // 2^29 [X_2, X_1] = 0 that comes from 2 X_3 = [X_2, X_1] - X_3^2 and 2^30 X_3 = 0 is lost)
  for (int b = 0; b < ng; b++) {
    if (PR.ex[b] >= E) continue;
    u64 c = PP[E - PR.ex[b]];
    sm.acc.addsv(PR.pi[b], c); if (tailP[b] >= 0) sm.acc.add(tailP[b], c);
    push(sm.nf_acc());
  }
  // (E1) (p^e_b b - pi_b) X_j = 0
  for (int b = 0; b < ng; b++) {
    if (PR.ex[b] >= E) continue;
    for (int j = 0; j < R; j++) {
      u64 pe = PP[PR.ex[b]];
      sm.acc.addsv(PR.mu[b][j], pe); if (tailX[b][j] >= 0) sm.acc.add(tailX[b][j], pe);
      const SV& s = PR.pi[b];
      for (size_t q = 0; q < s.size(); q++) {
        int c = s.i[q]; u64 m = negm(s.v[q]);
        sm.acc.addsv(PR.mu[c][j], m); if (tailX[c][j] >= 0) sm.acc.add(tailX[c][j], m);
      }
      push(sm.nf_acc());
    }
  }
  size_t ne1 = rows.size();  // (E0) and (E1)
  // (E2) b (rho - 1) = 0 for every generator b of weight <= k-1
  vector<Acc> res(magnus.size()); for (auto& a : res) a.init(ng + NT);
  for (int b = 0; b < ng; b++) {
    SV u; u.i.push_back(b); u.v.push_back(1);
    DFSCtx C{&sm, &res, k, PR.wt[b]};
    dfs(C, u, 0, 0);
    // the rows of b (one per relator) involve few tails: replace them by their Howell form, on their
    // own columns (same lattice, at most as many rows as columns)
    size_t r0 = rows.size();
    for (auto& a : res) { sm.acc.clear(); for (int x : a.t) if (a.a[x]) sm.acc.add(x, a.a[x]); a.clear(); push(sm.nf_acc()); }
    if (rows.size() - r0 > 1) {
      vector<int> cols; for (size_t q = r0; q < rows.size(); q++) cols.insert(cols.end(), rows[q].i.begin(), rows[q].i.end());
      sort(cols.begin(), cols.end()); cols.erase(unique(cols.begin(), cols.end()), cols.end());
      if (cols.size() < rows.size() - r0) {
        vector<Row> loc(rows.begin() + r0, rows.end()); rows.resize(r0);
        for (auto& r : loc) for (auto& c : r.i) c = lower_bound(cols.begin(), cols.end(), c) - cols.begin();
        vector<int> lpv, lord; vector<Row> lp = howell_fixed(loc, cols.size(), lpv, lord);
        for (auto& r : lp) { if (r.i.empty()) continue; for (auto& c : r.i) c = cols[c]; rows.push_back(std::move(r)); }
      }
    }
  }
  size_t ne2 = rows.size() - ne1;
  if (badgen) { printf("ERROR stage %d: %lld nonzero generator entries in the equations (R_k inconsistent)\n", k, badgen); exit(3); }
  double t1 = now();
  vector<int> pv, order;
  long long nrow = rows.size(), nent = 0; for (auto& r : rows) nent += r.i.size();
  ST_ELIM = ST_FILL = 0;
  vector<Row> piv = HMETH == 2 ? howell_dyn(rows, NT, pv, order) : HMETH == 1 ? howell_fixed(rows, NT, pv, order) : howell_stream(rows, NT, pv, order);
  double t2 = now();
  { long long npiv = 0, plen = 0, pmax = 0; for (int c = 0; c < NT; c++) if (pv[c] >= 0) { npiv++; plen += piv[c].i.size(); pmax = max(pmax, (long long)piv[c].i.size()); }
    printf("  howell %s: %lld rows (%lld entries) x %d columns; %lld eliminations writing %lld entries; %lld pivots, length mean %.0f max %lld\n",
           HMETH == 2 ? "dyn" : HMETH == 1 ? "fixed" : "stream", nrow, nent, NT, ST_ELIM, ST_FILL, npiv, npiv ? (double)plen / npiv : 0.0, pmax); }
  // rest[c]: the pivot row of c without its pivot entry, with the unit-pivot columns substituted
  // (last pivot first: the rows of later columns are already reduced, and contain none)
  vector<SV> rest(NT);
  { Acc acc; acc.init(NT);
    for (int q = (int)order.size() - 1; q >= 0; q--) {
      int c = order[q]; if (pv[c] < 0) continue;
      const Row& r = piv[c];
      for (size_t t = 0; t < r.i.size(); t++) {
        int cc = r.i[t]; if (cc == c) continue;
        if (pv[cc] == 0) acc.addsv(rest[cc], negm(r.v[t]));  // cc = -rest[cc]
        else acc.add(cc, r.v[t]);
      }
      rest[c] = acc.take();
      Row().i.swap(piv[c].i); vector<u64>().swap(piv[c].v);
    } }
  // new generators: the surviving tail columns (no pivot, or pivot p^v with v > 0), in the order
  vector<int> newidx(NT, -1); int nnew = 0;
  for (int c : order) if (pv[c] != 0) newidx[c] = ng + nnew++;
  int ngnew = ng + nnew;
  Acc acc2; acc2.init(ngnew);
  auto mapsv = [&](const SV& r, bool neg) {  // over the new generators, sorted
    for (size_t q = 0; q < r.size(); q++) { int nc = newidx[r.i[q]]; if (nc < 0) { printf("ERROR: unreduced\n"); exit(3); } acc2.add(nc, neg ? negm(r.v[q]) : r.v[q]); }
    return acc2.take();
  };
  auto texpr = [&](int c) {  // expression of tail column c over the new generators
    if (pv[c] == 0) return mapsv(rest[c], true);  // c + rest = 0
    SV s; s.i.push_back(newidx[c]); s.v.push_back(1); return s;
  };
  auto addsv = [&](const SV& a, const SV& b) { acc2.addsv(a, 1); acc2.addsv(b, 1); return acc2.take(); };
  for (int b = 0; b < ng; b++) {
    if (tailP[b] >= 0) PR.pi[b] = addsv(PR.pi[b], texpr(tailP[b] - ng));
    for (int j = 0; j < R; j++) if (tailX[b][j] >= 0) PR.mu[b][j] = addsv(PR.mu[b][j], texpr(tailX[b][j] - ng));
  }
  long long logv = 0, nfree = 0;
  for (int c : order) {
    if (pv[c] == 0) continue;
    PR.wt.push_back(k); PR.mu.push_back(vector<SV>(R));
    PR.defb.push_back(slotb[c]); PR.defj.push_back(slotj[c]); PR.isdefX.push_back(vector<char>(R, 0)); PR.isdefP.push_back(0);
    if (slotj[c] < 0) PR.isdefP[slotb[c]] = 1; else PR.isdefX[slotb[c]][slotj[c]] = 1;
    if (pv[c] < 0) { PR.ex.push_back(E); PR.pi.push_back(SV()); nfree++; logv += E; continue; }
    PR.ex.push_back(pv[c]); logv += pv[c];
    PR.pi.push_back(mapsv(rest[c], true));  // p^v c = -rest
  }
  PR.ngen = ngnew;
  tailP.clear(); tailX.clear(); NT = 0;
  double t3 = now();
  printf("stage %d: %d tails, %zu + %zu equations, %d new generators of weight %d (%lld without power relation), log_%d |Delta^%d/Delta^%d| = %lld; %.1f + %.1f + %.1f s\n",
         k, (int)newidx.size(), ne1, ne2, nnew, k, nfree, P, k, k + 1, logv, t1 - t0, t2 - t1, t3 - t2);
  fflush(stdout);
  return false;
}

// the final module (no tails)
struct FinalMod {
  StageMod sm;
  SV mulX(const SV& v, int j) { return sm.mulX(v, j); }
};

int main(int argc, char** argv) {
  string t;
  auto expect = [&](const char* w) { t = tok(); if (t != w) { fprintf(stderr, "expected %s got %s\n", w, t.c_str()); exit(2); } };
  expect("p"); P = atoi(tok().c_str()); expect("E"); E = atoi(tok().c_str()); expect("n"); NDEG = atoi(tok().c_str()); expect("r"); R = atoi(tok().c_str());
  if (argc > 1) NDEG = atoi(argv[1]);  // override n of the input
  { const char* h = getenv("GRNQ_HOWELL"); string hs = h ? h : "stream"; HMETH = hs == "fixed" ? 1 : hs == "dyn" ? 2 : 0; }
  { u128 d = 1; for (int q = 0; q < E; q++) d *= P; if (d >= ((u128)1 << 62)) { fprintf(stderr, "p^E too large\n"); return 2; } D = (u64)d; }
  PP.assign(E + 1, 1); for (int q = 1; q <= E; q++) PP[q] = PP[q - 1] * P;
  SMALLD = D < ((u64)1 << 32); if (SMALLD) BARM = (u64)((((u128)1) << 64) / D);
  t = tok();
  while (t == "let") { string nm = tok(); PEx e = parse(); NAMES.push_back({nm, e}); t = tok(); }
  if (t != "rels") { fprintf(stderr, "expected rels got %s\n", t.c_str()); exit(2); }
  int S = atoi(tok().c_str());
  vector<PEx> rels; for (int s = 0; s < S; s++) rels.push_back(parse());
  expect("tests"); int NTs = atoi(tok().c_str());
  vector<string> tn; vector<PEx> tests;
  for (int s = 0; s < NTs; s++) { tn.push_back(tok()); tests.push_back(parse()); }
  // spans: NAME k e_1 .. e_k -- the set of a in F_p^k with prod e_i^a_i in D_n, by additivity (below)
  vector<string> sn; vector<vector<PEx>> spans;
  t = tok();
  if (t == "spans") { int NS = atoi(tok().c_str());
    for (int s = 0; s < NS; s++) { sn.push_back(tok()); int k = atoi(tok().c_str()); vector<PEx> v; for (int q = 0; q < k; q++) v.push_back(parse()); spans.push_back(v); } }
  FT = new FreeT();
  { const char* pj = getenv("GRNQ_PROJ"); if (pj) { PROJ = atoi(pj); PROJ_N = tn; PROJ_T = tests; } }
  printf("p = %d, E = %d, n = %d, r = %d, %d relators, %d tests; |T_<n| = %lld\n", P, E, NDEG, R, S, NTs, FT->size);
  double tm0 = now();
  for (auto& rho : rels) {
    vector<u64> m = FT->magnus(rho);
    m[0] = (m[0] + D - 1) % D;  // rho - 1
    magnus.push_back(std::move(m));
  }
  live = subtree_nz(magnus);
  printf("Magnus expansions of %zu named subexpressions and %d relators: %.1f s\n", NAMES.size(), S, now() - tm0); fflush(stdout);
  PR.mu[0].assign(R, SV()); PR.ex[0] = E; PR.isdefX[0].assign(R, 0);
  for (int k = 1; k < NDEG; k++) if (stage(k)) { printf("grnq done (projection test)\n"); return 0; }
  // weights
  { vector<int> cnt(NDEG, 0); for (int b = 0; b < PR.ngen; b++) cnt[PR.wt[b]]++;
    printf("generators by weight:"); for (int w = 0; w < NDEG; w++) printf(" %d", cnt[w]);
    int emax = 0; for (int b = 1; b < PR.ngen; b++) if (PR.ex[b] < E) emax = max(emax, PR.ex[b]);
    printf("; largest exponent of a power relation %d (E = %d)\n", emax, E); }
  // certificate: p^(E-1) kills every generator of weight >= 1
  FinalMod fm; long long bad = 0;
  for (int b = 1; b < PR.ngen; b++) { SV s; s.i.push_back(b); s.v.push_back(PP[E - 1]); if (fm.sm.nf(s).size()) bad++; }
  printf("certificate (p^(E-1) Delta in Delta^%d + p^E): %s%s\n", NDEG, bad ? "FAILS" : "holds", bad ? " -- membership modulo p^E only, raise E" : "");
  // h - 1 = sum_m c_m m in T; its image is sum_m c_m (1 . m), by the same walk as (E2) with b = 1
  auto image = [&](const PEx& h) {
    vector<vector<u64>> c1(1, FT->magnus(h));
    c1[0][0] = (c1[0][0] + D - 1) % D;
    vector<vector<u64>> save; save.swap(magnus); magnus.swap(c1);
    vector<char> savel = live; live = subtree_nz(magnus);
    vector<Acc> res(1); res[0].init(PR.ngen);
    SV u; u.i.push_back(0); u.v.push_back(1);
    DFSCtx C{&fm.sm, &res, NDEG, 0};
    dfs(C, u, 0, 0);
    SV x = res[0].take(); x = fm.sm.nf(x);
    magnus.swap(save); live = savel;
    return x;
  };
  auto weight = [&](const SV& x) { int w = NDEG; for (int q : x.i) w = min(w, PR.wt[q]); return w; };
  for (int s = 0; s < NTs; s++) {
    SV x = image(tests[s]);
    int w = weight(x);
    if (w >= NDEG) printf("test %s: h - 1 in Delta^%d\n", tn[s].c_str(), NDEG);
    else printf("test %s: h - 1 in Delta^%d, not in Delta^%d\n", tn[s].c_str(), w, w + 1);
    fflush(stdout);
  }
  // spans: if (e_i^a - 1)(e_j^b - 1) lies in Delta^n for all i != j (the two smallest weights add up to
  // >= n), then prod e_i^a_i - 1 = sum_i (e_i^a_i - 1) mod Delta^n (expand the product: every term with
  // two or more factors vanishes), so the a in {0..p-1}^k with prod e_i^a_i in D_n are those with
  // sum_i x_i(a_i) = 0, x_i(a) the image of e_i^a - 1 (computed for each a); all p^k are tried.
  vector<PEx> keep;  // FreeT::magnus memoizes by address: the nodes made here must outlive the run
  for (size_t s = 0; s < spans.size(); s++) {
    int k = spans[s].size(); vector<vector<SV>> x(k, vector<SV>(P)); vector<int> wv(k);
    printf("span %s: weights", sn[s].c_str());
    for (int q = 0; q < k; q++) {
      for (int a = 1; a < P; a++) { auto e = make_shared<Ex>(); e->op = 2; e->n = a; e->c.push_back(spans[s][q]); keep.push_back(e); x[q][a] = image(e); }
      wv[q] = weight(x[q][1]); printf(" %d", wv[q]);
    }
    printf("\n");
    vector<int> sw = wv; sort(sw.begin(), sw.end());
    if (k >= 2 && sw[0] + sw[1] < NDEG) { printf("span %s: not additive (%d + %d < %d), skipped\n", sn[s].c_str(), sw[0], sw[1], NDEG); continue; }
    long long tot = 1; for (int q = 0; q < k; q++) tot *= P;
    long long nker = 0; vector<int> a(k, 0);
    for (long long c = 0; c < tot; c++) {
      long long y = c; for (int q = 0; q < k; q++) { a[q] = y % P; y /= P; }
      Acc acc; acc.init(PR.ngen); for (int q = 0; q < k; q++) if (a[q]) acc.addsv(x[q][a[q]], 1);
      SV z = acc.take(); z = fm.sm.nf(z);
      if (!z.size()) { nker++; if (c) { printf("span %s: in D_%d:", sn[s].c_str(), NDEG); for (int q = 0; q < k; q++) printf(" %d", a[q]); printf("\n"); } }
    }
    printf("span %s: %lld of %lld combinations in D_%d (log_%d = %d)\n", sn[s].c_str(), nker, tot, NDEG, P, (int)round(log((double)nker) / log((double)P)));
    fflush(stdout);
  }
  printf("grnq done\n");
  return 0;
}
