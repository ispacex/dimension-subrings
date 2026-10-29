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
static u64 D;
static vector<u64> PP;

static inline u64 mulm(u64 a, u64 b) { return (u64)((u128)a * b % D); }
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
// rows over columns [0, ncol); returns pivot rows indexed by pivot column (empty Row if none), entry p^v at the pivot
static vector<Row> howell(vector<Row>& rows, int ncol, vector<int>& pv) {
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
      Row s = axpy(r, pr, negm(q));
      if (!s.i.empty()) bucket[lead(s)].push_back(std::move(s));
    }
    vector<Row>().swap(B);
    if (bv > 0) { Row s = pr; scale(s, PP[E - bv]); if (!s.i.empty()) bucket[lead(s)].push_back(std::move(s)); }
    pv[c] = bv; piv[c] = std::move(pr);
  }
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

static void stage(int k) {  // PR = R_k (generators of weight <= k-1) -> R_{k+1}
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
  StageMod sm;
  vector<Row> rows;
  long long badgen = 0;
  auto push = [&](const SV& s) {
    Row r;
    for (size_t q = 0; q < s.size(); q++) { if (s.i[q] < ng) { badgen++; continue; } r.i.push_back(s.i[q] - ng); r.v.push_back(s.v[q]); }
    if (!r.i.empty()) rows.push_back(std::move(r));
  };
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
  size_t ne1 = rows.size();
  // (E2) b (rho - 1) = 0 for every generator b of weight <= k-1
  vector<Acc> res(magnus.size()); for (auto& a : res) a.init(ng + NT);
  for (int b = 0; b < ng; b++) {
    SV u; u.i.push_back(b); u.v.push_back(1);
    DFSCtx C{&sm, &res, k, PR.wt[b]};
    dfs(C, u, 0, 0);
    for (auto& a : res) { sm.acc.clear(); for (int x : a.t) if (a.a[x]) sm.acc.add(x, a.a[x]); a.clear(); push(sm.nf_acc()); }
  }
  size_t ne2 = rows.size() - ne1;
  if (badgen) { printf("ERROR stage %d: %lld nonzero generator entries in the equations (R_k inconsistent)\n", k, badgen); exit(3); }
  double t1 = now();
  vector<int> pv;
  vector<Row> piv = howell(rows, NT, pv);
  double t2 = now();
  // back-substitute the unit pivots (last to first), so that every row involves surviving tails only
  for (int c = NT - 1; c >= 0; c--) {
    if (pv[c] < 0) continue;
    Row& r = piv[c]; Row out; out.i.push_back(r.i[0]); out.v.push_back(r.v[0]);
    Row rest; rest.i.assign(r.i.begin() + 1, r.i.end()); rest.v.assign(r.v.begin() + 1, r.v.end());
    // eliminate unit-pivot columns from rest (their rows are already reduced)
    bool again = true;
    while (again) {
      again = false;
      for (size_t q = 0; q < rest.i.size(); q++) {
        int cc = rest.i[q];
        if (pv[cc] == 0) { u64 a = rest.v[q]; Row tail; tail.i.assign(piv[cc].i.begin() + 1, piv[cc].i.end()); tail.v.assign(piv[cc].v.begin() + 1, piv[cc].v.end());
          Row z; z.i.push_back(cc); z.v.push_back(a);
          rest = axpy(rest, z, negm(1)); rest = axpy(rest, tail, negm(a)); again = true; break; }
      }
    }
    out.i.insert(out.i.end(), rest.i.begin(), rest.i.end()); out.v.insert(out.v.end(), rest.v.begin(), rest.v.end());
    r = std::move(out);
  }
  // new generators: surviving tail columns (no pivot, or pivot p^v with v > 0)
  vector<int> newidx(NT, -1); int nnew = 0;
  for (int c = 0; c < NT; c++) if (pv[c] != 0) newidx[c] = ng + nnew++;
  // expression of each tail column over the new generators
  auto texpr = [&](int c) {
    SV s;
    if (pv[c] == 0) {  // c = -(rest)
      const Row& r = piv[c];
      for (size_t q = 1; q < r.i.size(); q++) { int nc = newidx[r.i[q]]; if (nc < 0) { printf("ERROR: unreduced\n"); exit(3); } s.i.push_back(nc); s.v.push_back(negm(r.v[q])); }
    } else { s.i.push_back(newidx[c]); s.v.push_back(1); }
    return s;
  };
  auto addsv = [&](const SV& a, const SV& b) { Acc t; t.init(ng + nnew); t.addsv(a, 1); t.addsv(b, 1); return t.take(); };
  int ngnew = ng + nnew;
  for (int b = 0; b < ng; b++) {
    if (tailP[b] >= 0) PR.pi[b] = addsv(PR.pi[b], texpr(tailP[b] - ng));
    for (int j = 0; j < R; j++) if (tailX[b][j] >= 0) PR.mu[b][j] = addsv(PR.mu[b][j], texpr(tailX[b][j] - ng));
  }
  long long logv = 0, nfree = 0;
  for (int c = 0; c < NT; c++) {
    if (pv[c] == 0) continue;
    PR.wt.push_back(k); PR.mu.push_back(vector<SV>(R));
    PR.defb.push_back(slotb[c]); PR.defj.push_back(slotj[c]); PR.isdefX.push_back(vector<char>(R, 0)); PR.isdefP.push_back(0);
    if (slotj[c] < 0) PR.isdefP[slotb[c]] = 1; else PR.isdefX[slotb[c]][slotj[c]] = 1;
    if (pv[c] < 0) { PR.ex.push_back(E); PR.pi.push_back(SV()); nfree++; logv += E; continue; }
    PR.ex.push_back(pv[c]); logv += pv[c];
    SV s; const Row& r = piv[c];
    for (size_t q = 1; q < r.i.size(); q++) { s.i.push_back(newidx[r.i[q]]); s.v.push_back(negm(r.v[q])); }
    PR.pi.push_back(s);
  }
  PR.ngen = ngnew;
  tailP.clear(); tailX.clear(); NT = 0;
  double t3 = now();
  printf("stage %d: %d tails, %zu + %zu equations, %d new generators of weight %d (%lld without power relation), log_%d |Delta^%d/Delta^%d| = %lld; %.1f + %.1f + %.1f s\n",
         k, (int)newidx.size(), ne1, ne2, nnew, k, nfree, P, k, k + 1, logv, t1 - t0, t2 - t1, t3 - t2);
  fflush(stdout);
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
  { u128 d = 1; for (int q = 0; q < E; q++) d *= P; if (d >= ((u128)1 << 62)) { fprintf(stderr, "p^E too large\n"); return 2; } D = (u64)d; }
  PP.assign(E + 1, 1); for (int q = 1; q <= E; q++) PP[q] = PP[q - 1] * P;
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
  for (int k = 1; k < NDEG; k++) stage(k);
  // weights
  { vector<int> cnt(NDEG, 0); for (int b = 0; b < PR.ngen; b++) cnt[PR.wt[b]]++;
    printf("generators by weight:"); for (int w = 0; w < NDEG; w++) printf(" %d", cnt[w]); printf("\n"); }
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
  // spans: if (e_i - 1)(e_j - 1) lies in Delta^n for all i, j (weights adding up to >= n), then
  // prod e_i^a_i - 1 = sum a_i (e_i - 1) mod Delta^n for integers a_i >= 0 (the products of two or more
  // factors e_i - 1 vanish), so the a in {0..p-1}^k with prod e_i^a_i in D_n are those with
  // sum a_i x_i = 0, x_i the image of e_i - 1; all p^k of them are tried.
  for (size_t s = 0; s < spans.size(); s++) {
    int k = spans[s].size(); vector<SV> x(k); vector<int> wv(k);
    printf("span %s: weights", sn[s].c_str());
    for (int q = 0; q < k; q++) { x[q] = image(spans[s][q]); wv[q] = weight(x[q]); printf(" %d", wv[q]); }
    int wmin = NDEG; for (int q = 0; q < k; q++) wmin = min(wmin, wv[q]);
    printf("\n");
    if (2 * wmin < NDEG) { printf("span %s: not additive (2 * %d < %d), skipped\n", sn[s].c_str(), wmin, NDEG); continue; }
    long long tot = 1; for (int q = 0; q < k; q++) tot *= P;
    long long nker = 0; vector<int> a(k, 0);
    for (long long c = 0; c < tot; c++) {
      long long y = c; for (int q = 0; q < k; q++) { a[q] = y % P; y /= P; }
      Acc acc; acc.init(PR.ngen); for (int q = 0; q < k; q++) acc.addsv(x[q], (u64)a[q]);
      SV z = acc.take(); z = fm.sm.nf(z);
      if (!z.size()) { nker++; if (c) { printf("span %s: in D_%d:", sn[s].c_str(), NDEG); for (int q = 0; q < k; q++) printf(" %d", a[q]); printf("\n"); } }
    }
    printf("span %s: %lld of %lld combinations in D_%d (log_%d = %d)\n", sn[s].c_str(), nker, tot, NDEG, P, (int)round(log((double)nker) / log((double)P)));
    fflush(stdout);
  }
  printf("grnq done\n");
  return 0;
}
