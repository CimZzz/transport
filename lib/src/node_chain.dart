typedef onDrop<T> = void Function(NodeChain<T> nodeChain);

class NodeChain<T> {
	NodeChain(this.nodeData, {bool isRoot, onDrop<T> onDrop}):
		_onDrop = onDrop {
		tailNode = this;
		headNode = this;
	}
	
	final T nodeData;
	final onDrop<T> _onDrop;
	
	NodeChain previousNode;
	NodeChain nextNode;
	NodeChain parentNode;
	NodeChain childNode;
	/// Tail node
	/// only head node contain this node
	NodeChain tailNode;
	/// Head node
	/// only tail node contain this node
	NodeChain headNode;
	
	void forEach(void Function(NodeChain nodeChain) callback, {bool fromTail = false}) {
		fromTail = fromTail == true && tailNode != null;
		if(fromTail) {
			var nodeChain = tailNode;
			while(nodeChain != null) {
				callback(nodeChain);
				nodeChain = nodeChain.previousNode;
			}
		}
		else {
			NodeChain nodeChain = this;
			while(nodeChain != null) {
				callback(nodeChain);
				nodeChain = nodeChain.nextNode;
			}
		}
	}
	
	/// Add cousin node
	void addCousin(NodeChain newCousin, {bool insertTail = true}) {
		insertTail = insertTail == true && tailNode != null;
		if(insertTail) {
			// tail node never `null`
			// new child must leaf node on same level
			newCousin.previousNode = tailNode;
			tailNode.nextNode = newCousin;
			
			tailNode.headNode = null;
			tailNode = newCousin.tailNode;
			newCousin.tailNode?.headNode = this;
			newCousin.tailNode = null;
		}
		else {
			if(headNode == null) {
				// not tail
				nextNode.previousNode = newCousin.tailNode;
				newCousin.tailNode.nextNode = nextNode;
				newCousin.previousNode = this;
				nextNode = newCousin;
				
				newCousin.headNode = null;
				newCousin.tailNode?.headNode = null;
				newCousin.tailNode = null;
			}
			else {
				nextNode = newCousin;
				newCousin.previousNode = newCousin;
				newCousin.tailNode.headNode = headNode;
				newCousin.tailNode = null;
			}
		}
	}
	
	/// Add child node
	void addChild(NodeChain newChild, {bool insertHead = true}) {
		insertHead = insertHead == true || childNode == null;
		if(insertHead) {
			newChild.parentNode = this;
			newChild.nextNode = childNode;
			newChild.headNode = childNode == null ? newChild : childNode.headNode;
			newChild.tailNode = childNode == null ? newChild : childNode.tailNode;
			newChild.tailNode?.headNode = newChild;
			childNode?.headNode = null;
			childNode?.tailNode = null;
			childNode?.previousNode = newChild;
			childNode?.parentNode = null;
			childNode = newChild;
		}
		else {
			// child node never `null`
			addCousin(newChild, insertTail: false);
		}
	}
	
	/// Drop self and children
	void dropSelf() {
		if(parentNode != null || previousNode == null) {
			// child node head
			nextNode?.parentNode = parentNode;
			nextNode?.tailNode = tailNode;
			nextNode?.previousNode = null;
			parentNode?.childNode = nextNode;
			tailNode?.headNode = headNode;
			previousNode = null;
			nextNode = null;
			parentNode = null;
			while(childNode != null) {
				childNode.dropSelf();
			}
			childNode = null;
		}
		else {
			nextNode?.previousNode = previousNode;
			previousNode?.nextNode = nextNode;
			previousNode?.headNode = headNode;
			nextNode = null;
			previousNode = null;
			while(childNode != null) {
				childNode.dropSelf();
			}
			childNode = null;
		}
		_onDrop?.call(this);
	}
	
	@override
    String toString() => nodeData.toString();
}