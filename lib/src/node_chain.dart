typedef onDrop<T> = void Function(T nodeData);

class NodeChain<T> {
	NodeChain(this.nodeData, {onDrop<T> onDrop}):
		_onDrop = onDrop;
	
	final T nodeData;
	final onDrop<T> _onDrop;
	
	NodeChain previousNode;
	NodeChain nextNode;
	NodeChain parentNode;
	NodeChain childNode;
	/// Tail node
	/// only head contain this node
	NodeChain tailNode;
	
	/// Add cousin node
	void addCousin(NodeChain newCousin, {bool insertHead = true}) {
	
	}
	
	/// Add child node
	void addChild(NodeChain newChild, {bool insertHead = true}) {
		insertHead ??= true;
		insertHead = insertHead || childNode == null;
		if(insertHead) {
			newChild.parentNode = this;
			newChild.nextNode = childNode;
			newChild.tailNode = childNode == null ? newChild : childNode.tailNode;
			childNode?.tailNode = null;
			childNode?.previousNode = newChild;
			childNode?.parentNode = null;
			childNode = newChild;
		}
		else {
			// child node never `null`
			// new child must leaf node on same level
			newChild.previousNode = childNode.tailNode;
			childNode.tailNode.nextNode = newChild;
			childNode.tailNode = newChild;
		}
	}
	
	/// Drop self and children
	void dropSelf() {
		if(parentNode != null) {
			// child node head
			nextNode?.parentNode = parentNode;
			nextNode?.previousNode = null;
			parentNode?.childNode = nextNode;
			previousNode = null;
			nextNode = null;
			parentNode = null;
			childNode?.dropSelf();
			childNode = null;
		}
		else {
			nextNode?.previousNode = previousNode;
			previousNode?.nextNode = nextNode;
			nextNode = null;
			previousNode = null;
			childNode?.dropSelf();
			childNode = null;
		}
		_onDrop?.call(nodeData);
	}
}