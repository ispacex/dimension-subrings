from lat import Group
def affine(n, units, gens):
    mul = lambda g, h: ((g[0]*h[0]) % n, (g[0]*h[1] + g[1]) % n)
    return Group(gens, mul, (1, 0))
def quat():
    def mul(p, q):
        a1,b1,c1,d1 = p; a2,b2,c2,d2 = q
        return (a1*a2-b1*b2-c1*c2-d1*d2, a1*b2+b1*a2+c1*d2-d1*c2, a1*c2-b1*d2+c1*a2+d1*b2, a1*d2+b1*c2-c1*b2+d1*a2)
    return Group([(0,1,0,0),(0,0,1,0)], mul, (1,0,0,0))
D8 = affine(4, None, [(-1 % 4, 0), (-1 % 4, 1)])
Q8 = quat()
M16 = affine(8, None, [(1, 1), (5, 0)])
