import unittest
import json

import networkx as nx

from pybhcd import bhcd

class TestBHCD(unittest.TestCase):
    def test_basic_routine(self):
        G = nx.Graph()
        G.add_edge(0,1)
        G.add_edge(2,3) 
        result_json_obj = bhcd(G)
        print(json.dumps(result_json_obj, indent=4))
 
if __name__ == '__main__':
    unittest.main()
