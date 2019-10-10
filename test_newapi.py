import unittest

import networkx as nx

from pybhcd import bhcd

class TestBHCD(unittest.TestCase):
    def test_basic_routine(self):
        G = nx.Graph()
        G.add_edge(0,1)
        G.add_edge(2,3) 
        result_str = bhcd(G)
        print(result_str)
 
if __name__ == '__main__':
    unittest.main()
