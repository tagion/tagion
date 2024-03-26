module ddom.VNode;
/*
#include <emscripten/val.h>
#include <vector>
#include <string>
#ifdef ASMDOM_JS_SIDE
  #include <map>
#else
  #include <functional>
  #include <utility>
  #include <unordered_map>
#endif

namespace asmdom {
*/
/*
  #ifdef ASMDOM_JS_SIDE
    typedef std::map<std::string, std::string> Attrs;
  #else
    typedef std::function<bool(emscripten::val)> Callback;
    typedef std::unordered_map<std::string, std::string> Attrs;
    typedef std::unordered_map<std::string, emscripten::val> Props;
    typedef std::unordered_map<std::string, Callback> Callbacks;
  #endif
*/
  enum VNodeFlags {
    // NodeType
    isElement = 1,
    isText = 1 << 1,
    isComment = 1 << 2,
    isFragment = 1 << 3,

    // flags
    hasKey = 1 << 4,
    hasText = 1 << 5,
    hasAttrs = 1 << 6,
    hasProps = 1 << 7,
    hasCallbacks = 1 << 8,
    hasDirectChildren = 1 << 9,
    hasChildren = hasDirectChildren | hasText,
    hasRef = 1 << 10,
    hasNS = 1 << 11,
    isNormalized = 1 << 12,

    // masks
    isElementOrFragment = isElement | isFragment,
    nodeType = isElement | isText | isComment | isFragment,
    removeNodeType = ~0 ^ nodeType,
    extractSel = ~0 << 13,
    id = extractSel | hasKey | nodeType
  }

struct Data {

    //Data() {};
    version(ASMDOM_JS_SIDE) {
      this(
        ref const Data data
      ): attrs(data.attrs) {
      };
      Data(
        ref const Attrs dataAttrs
      ): attrs(dataAttrs) {};
    }
    else {
      Data(
        ref const Data data
      ): attrs(data.attrs), props(data.props), callbacks(data.callbacks) {};
      Data(
        const Attrs& dataAttrs,
        const Props& dataProps = Props(),
        const Callbacks& dataCallbacks = Callbacks()
      ): attrs(dataAttrs), props(dataProps), callbacks(dataCallbacks) {};
      Data(
        const Attrs& dataAttrs,
        const Callbacks& dataCallbacks
      ): attrs(dataAttrs), callbacks(dataCallbacks) {};
      Data(
        const Props& dataProps,
        const Callbacks& dataCallbacks = Callbacks()
      ): props(dataProps), callbacks(dataCallbacks) {};
      Data(
        const Callbacks& dataCallbacks
      ): callbacks(dataCallbacks) {};
    #endif

    Attrs attrs;
    #ifndef ASMDOM_JS_SIDE
      Props props;
      Callbacks callbacks;
    #endif
  };
/*
struct VNode {
    private:
      void normalize(const bool injectSvgNamespace);
    public:
      VNode(
        const std::string& nodeSel
      ): sel(nodeSel) {};
      VNode(
        const std::string& nodeSel,
        const std::string& nodeText
      ): sel(nodeSel) {
        normalize();
        if (hash & isComment) {
          sel = nodeText;
        } else {
          children.push_back(new VNode(nodeText, true));
          hash |= hasText;
			  }
      };
      VNode(
        const std::string& nodeText,
        const bool textNode
      ) {
        if (textNode) {
          normalize();
          sel = nodeText;
          // replace current type with text type
			    hash = (hash & removeNodeType) | isText;
        } else {
          sel = nodeText;
          normalize();
        }
      };
      VNode(
        const std::string& nodeSel,
        const Data& nodeData
      ): sel(nodeSel), data(nodeData) {};
      VNode(
        const std::string& nodeSel,
        const std::vector<VNode*>& nodeChildren
      ): sel(nodeSel), children(nodeChildren) {};
      VNode(
        const std::string& nodeSel,
        VNode* child
      ): sel(nodeSel), children{ child } {};
      VNode(
        const std::string& nodeSel,
        const Data& nodeData,
        const std::string& nodeText
      ): sel(nodeSel), data(nodeData) {
        normalize();
        if (hash & isComment) {
          sel = nodeText;
        } else {
          children.push_back(new VNode(nodeText, true));
          hash |= hasText;
        }
      };
      VNode(
        const std::string& nodeSel,
        const Data& nodeData,
        const std::vector<VNode*>& nodeChildren
      ): sel(nodeSel), data(nodeData), children(nodeChildren) {};
      VNode(
        const std::string& nodeSel,
        const Data& nodeData,
        VNode* child
      ): sel(nodeSel), data(nodeData), children{ child } {};
      ~VNode();

      void normalize() { normalize(false); };

    // contains selector for elements and fragments, text for comments and textNodes
    std::string sel;
    std::string key;
    std::string ns;
    unsigned int hash = 0;
    Data data;
    int elm = 0;
    std::vector<VNode*> children;
  };

  void deleteVNode(const VNode* const vnode);

  typedef std::vector<VNode*> Children;

}

#endif
#include "VNode.hpp"
#ifndef ASMDOM_JS_SIDE
	#include <emscripten/val.h>
	#include <emscripten/bind.h>
#endif
#include <cstdint>
#include <string>
#include <unordered_map>
*/

uint currentHash = 0;
//	std::unordered_map<std::string, unsigned int> hashes;

uint[string] hashes;

struct VNode {
	void normalize(const bool injectSvgNamespace) {
		if (!(hash & isNormalized)) {
			if (data.attrs.count("key")) {
				hash |= hasKey;
				key = data.attrs["key"];
				data.attrs.erase("key");
			}

			if (sel[0] == '!') {
				hash |= isComment;
				sel = "";
			} 
            else {
				children.erase(std::remove(children.begin(), children.end(), (VNode*)NULL), children.end());

				Attrs::iterator it = data.attrs.begin();
				while (it != data.attrs.end()) {
					if (it->first == "ns") {
						hash |= hasNS;
						ns = it->second;
						it = data.attrs.erase(it);
					} else if (it->second == "false") {
						it = data.attrs.erase(it);
					} else {
						if (it->second == "true") {
							it->second = "";
						}
						++it;
					}
				}

				bool addNS = injectSvgNamespace || (sel[0] == 's' && sel[1] == 'v' && sel[2] == 'g');
				if (addNS) {
					hash |= hasNS;
					ns = "http://www.w3.org/2000/svg";
				}

				if (!data.attrs.empty()) hash |= hasAttrs;
				#ifndef ASMDOM_JS_SIDE
					if (!data.props.empty()) hash |= hasProps;
					if (!data.callbacks.empty()) hash |= hasCallbacks;
				#endif
				if (!children.empty()) {
					hash |= hasDirectChildren;

					Children::size_type i = children.size();
					while (i--) {
						children[i]->normalize(
							addNS && sel != "foreignObject"
						);
					}
				}

				if (sel[0] == '\0') {
					hash |= isFragment;
				} else {
					if (hashes[sel] == 0) {
						hashes[sel] = ++currentHash;
					}

					hash |= (hashes[sel] << 13) | isElement;

					#ifndef ASMDOM_JS_SIDE
						if ((hash & hasCallbacks) && data.callbacks.count("ref")) {
							hash |= hasRef;
						}
					#endif
				}
			}

			hash |= isNormalized;
		}
	};

	void deleteVNode(const VNode* const vnode) {
		if (!(vnode->hash & hasText)) {
			Children::size_type i = vnode->children.size();
			while (i--) deleteVNode(vnode->children[i]);
		}
		delete vnode;
  };

	~this() {
		if (hash & hasText) {
			Children::size_type i = children.size();
			while (i--) delete children[i];
		}
  };

	version(ASMDOM_JS_SIDE)

		emscripten::val functionCallback(const std::uintptr_t& vnode, std::string callback, emscripten::val event) {
			Callbacks cbs = reinterpret_cast<VNode*>(vnode)->data.callbacks;
			if (!cbs.count(callback)) {
				callback = "on" + callback;
			}
			return emscripten::val(cbs[callback](event));
		};

		EMSCRIPTEN_BINDINGS(function_callback) {
			emscripten::function("functionCallback", &functionCallback, emscripten::allow_raw_pointers());
		};

    }

}
